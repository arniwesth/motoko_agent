#include <algorithm>
#include <cstddef>
#include <cstdio>
#include <fstream>
#include <string>
#include <vector>

#define SOKOL_IMPL
#if defined(__EMSCRIPTEN__)
#define SOKOL_GLES3
#else
#define SOKOL_GLCORE
#endif
#include "sokol_app.h"
#include "sokol_gfx.h"
#include "sokol_glue.h"
#include "sokol_time.h"

#include "imgui.h"
#define SOKOL_IMGUI_IMPL
#include "sokol_imgui.h"

enum PulseKind { PULSE_NONE, PULSE_ERROR, PULSE_SUCCESS, PULSE_PROMPT };

struct AppState {
    std::vector<std::string> lines;
    std::string load_error;
    std::size_t current_line = 0;
    uint64_t last_ticks = 0;
    double line_timer = 0.0;
    double loop_pause_timer = 0.0;
    float speed_multiplier = 1.0f;
    bool paused = false;
    PulseKind pulse_kind = PULSE_NONE;
    double pulse_timer = 0.0;
};

static AppState state;
static sg_pass_action pass_action;

static bool contains(const std::string& line, const char* needle) {
    return line.find(needle) != std::string::npos;
}

static ImVec4 color_for_line(const std::string& line) {
    if (contains(line, "[failed]") || contains(line, "[FAIL]") || contains(line, "[ERROR]") || contains(line, "FAILED")) {
        return ImVec4(0.72f, 0.28f, 0.30f, 1.0f);
    }
    if (contains(line, "[done]") || contains(line, "[PASS]") || contains(line, "[OK]")) {
        return ImVec4(0.20f, 0.58f, 0.44f, 1.0f);
    }
    if (contains(line, "[reason]") || contains(line, "[tools]")) {
        return ImVec4(0.30f, 0.46f, 0.68f, 1.0f);
    }
    if (contains(line, "] >") || contains(line, "> continue") || contains(line, "> test") ||
        contains(line, "> analyze") || contains(line, "> run") || contains(line, "> search")) {
        return ImVec4(0.25f, 0.52f, 0.60f, 1.0f);
    }
    if (contains(line, "Runtime is reasoning") || contains(line, "AILANG built") || contains(line, "Loaded extensions")) {
        return ImVec4(0.42f, 0.44f, 0.45f, 1.0f);
    }
    if (line.rfind("##", 0) == 0 || line.rfind("###", 0) == 0) {
        return ImVec4(0.62f, 0.64f, 0.62f, 1.0f);
    }
    if (line.empty() || line.rfind("---", 0) == 0) {
        return ImVec4(0.28f, 0.30f, 0.30f, 1.0f);
    }
    return ImVec4(0.50f, 0.52f, 0.52f, 1.0f);
}

static double delay_for_line(const std::string& line) {
    if (line.empty() || line.rfind("---", 0) == 0)
        return 0.08;
    if (line.rfind("##", 0) == 0)
        return 0.14;
    if (contains(line, "] >") || contains(line, "> continue") || contains(line, "> test") ||
        contains(line, "> analyze") || contains(line, "> run") || contains(line, "> yes"))
        return 0.15;
    if (line.size() > 2 && line[0] == '|')
        return 0.10;
    if (contains(line, "[failed]") || contains(line, "[FAIL]") || contains(line, "[ERROR]") || contains(line, "FAILED"))
        return 0.65;
    if (contains(line, "[done]") || contains(line, "[PASS]") || contains(line, "[OK]"))
        return 0.45;
    if (contains(line, "Runtime is reasoning") || contains(line, "AILANG built") || contains(line, "Loaded extensions"))
        return 0.20;
    if (line.size() < 60)
        return 0.25;
    return 0.33;
}

static void load_log() {
    std::ifstream file("/assets/motoko.log");
    if (!file) {
        state.load_error = "could not load /assets/motoko.log";
        state.lines = {
            "[ERROR] /assets/motoko.log is missing from the preload bundle",
            "[INFO] rebuild with: make web",
        };
        return;
    }

    std::string line;
    while (std::getline(file, line)) {
        if (!line.empty() && line.back() == '\r') {
            line.pop_back();
        }
        state.lines.push_back(line);
    }

    if (state.lines.empty()) {
        state.load_error = "motoko.log loaded but contained no lines";
        state.lines.push_back("[ERROR] motoko.log is empty");
    }
}

static void configure_imgui_style() {
    ImGui::StyleColorsDark();
    ImGuiStyle& style = ImGui::GetStyle();
    style.WindowRounding = 0.0f;
    style.ChildRounding = 0.0f;
    style.FrameRounding = 0.0f;
    style.ScrollbarRounding = 0.0f;
    style.GrabRounding = 0.0f;
    style.WindowBorderSize = 1.0f;
    style.ChildBorderSize = 1.0f;
    style.FrameBorderSize = 0.0f;
    style.WindowPadding = ImVec2(10.0f, 8.0f);
    style.ItemSpacing = ImVec2(7.0f, 5.0f);

    ImVec4* colors = style.Colors;
    colors[ImGuiCol_Text] = ImVec4(0.64f, 0.66f, 0.66f, 1.0f);
    colors[ImGuiCol_WindowBg] = ImVec4(0.065f, 0.070f, 0.070f, 0.96f);
    colors[ImGuiCol_ChildBg] = ImVec4(0.055f, 0.058f, 0.058f, 0.98f);
    colors[ImGuiCol_Border] = ImVec4(0.18f, 0.20f, 0.20f, 0.95f);
    colors[ImGuiCol_TitleBg] = ImVec4(0.050f, 0.055f, 0.055f, 0.98f);
    colors[ImGuiCol_TitleBgActive] = ImVec4(0.070f, 0.078f, 0.078f, 0.98f);
    colors[ImGuiCol_Button] = ImVec4(0.105f, 0.115f, 0.115f, 0.95f);
    colors[ImGuiCol_ButtonHovered] = ImVec4(0.145f, 0.165f, 0.165f, 1.00f);
    colors[ImGuiCol_ButtonActive] = ImVec4(0.090f, 0.300f, 0.260f, 1.00f);
    colors[ImGuiCol_FrameBg] = ImVec4(0.100f, 0.108f, 0.108f, 0.98f);
    colors[ImGuiCol_FrameBgHovered] = ImVec4(0.130f, 0.150f, 0.150f, 1.00f);
    colors[ImGuiCol_FrameBgActive] = ImVec4(0.100f, 0.260f, 0.225f, 1.00f);
    colors[ImGuiCol_SliderGrab] = ImVec4(0.00f, 0.70f, 0.58f, 0.92f);
    colors[ImGuiCol_SliderGrabActive] = ImVec4(0.00f, 0.92f, 0.76f, 1.00f);
    colors[ImGuiCol_Separator] = ImVec4(0.22f, 0.24f, 0.24f, 1.0f);
}

static void draw_log_rows(int visible_count) {
    const int start = std::max(0, visible_count - 90);
    if (start > 0) {
        ImGui::TextColored(ImVec4(0.40f, 0.42f, 0.42f, 1.0f), "... %d earlier lines collapsed", start);
    }
    for (int i = start; i < visible_count; ++i) {
        const std::string& line = state.lines[(std::size_t)i];
        ImGui::PushStyleColor(ImGuiCol_Text, color_for_line(line));
        bool code = false;
        std::string segment;
        for (char ch : line) {
            if (ch == '`') {
                if (!segment.empty()) {
                    if (code) {
                        ImGui::PushStyleColor(ImGuiCol_Text, ImVec4(0.22f, 0.56f, 0.50f, 1.0f));
                    }
                    ImGui::Text("%s", segment.c_str());
                    if (code) {
                        ImGui::PopStyleColor();
                    }
                    segment.clear();
                    ImGui::SameLine(0.0f, 0.0f);
                }
                code = !code;
            } else {
                segment.push_back(ch);
            }
        }
        if (!segment.empty()) {
            if (code) {
                ImGui::PushStyleColor(ImGuiCol_Text, ImVec4(0.22f, 0.56f, 0.50f, 1.0f));
            }
            ImGui::Text("%s", segment.c_str());
            if (code) {
                ImGui::PopStyleColor();
            }
        } else {
            ImGui::NewLine();
        }
        ImGui::PopStyleColor();
    }
}

static void draw_status_strip() {
    const bool complete = state.current_line >= state.lines.size();
    const char* rstate = state.paused ? "paused" : (complete ? "idle" : "streaming");
    const ImVec4 gray(0.42f, 0.44f, 0.44f, 1.0f);
    const ImVec4 cyan(0.00f, 0.78f, 0.95f, 1.0f);
    const ImVec4 amber(1.0f, 0.75f, 0.0f, 1.0f);
    ImGui::Separator();
    char prefix[128];
    snprintf(prefix, sizeof(prefix), "model=gemma-4-26b | ext=context_mode, exa_search | %.1fx | ",
        (double)state.speed_multiplier);
    ImGui::TextColored(gray, "%s", prefix);
    ImGui::SameLine(0.0f, 0.0f);
    ImVec4 sc = complete ? gray : (state.paused ? amber : cyan);
    ImGui::TextColored(sc, "%s", rstate);
}

static void draw_tools_tab() {
    const ImVec4 name_col(0.00f, 0.86f, 0.72f, 1.0f);
    const ImVec4 desc_col(0.52f, 0.55f, 0.56f, 1.0f);
    const ImVec4 ok_col(0.00f, 0.86f, 0.58f, 1.0f);
    struct Tool { const char* name; const char* desc; };
    static const Tool tools[] = {
        {"ExaSearch",       "search the web via Exa"},
        {"ExaFetch",        "fetch URL content via Exa"},
        {"ExaCrawl",        "crawl and extract via Exa"},
        {"CtxExecute",      "execute context-mode command"},
        {"CtxBatchExecute", "batch execute commands"},
        {"CtxSearch",       "search indexed context"},
        {"CtxIndex",        "index content for retrieval"},
        {"CtxStats",        "context-mode statistics"},
        {"CtxDoctor",       "diagnose context-mode setup"},
        {"BashExec",        "execute shell commands"},
        {"ReadFile",        "read file contents"},
        {"WriteFile",       "write file contents"},
    };
    ImGui::TextColored(desc_col, "Registered tools (%d):", (int)(sizeof(tools) / sizeof(tools[0])));
    ImGui::Separator();
    for (const auto& t : tools) {
        ImGui::TextColored(name_col, "%s", t.name);
        ImGui::SameLine(170.0f);
        ImGui::TextColored(desc_col, "%s", t.desc);
        ImGui::SameLine(0.0f, 10.0f);
        ImGui::TextColored(ok_col, "ready");
    }
}

static void draw_extensions_tab() {
    const ImVec4 name_col(0.00f, 0.78f, 0.95f, 1.0f);
    const ImVec4 ver_col(0.52f, 0.55f, 0.56f, 1.0f);
    const ImVec4 ok_col(0.00f, 0.86f, 0.58f, 1.0f);
    struct Ext { const char* name; const char* version; };
    static const Ext exts[] = {
        {"context_mode",  "v1.2.0"},
        {"exa_search",    "v0.8.1"},
        {"omnigraph",     "v0.3.0"},
        {"compaction_ai", "v1.0.2"},
    };
    ImGui::TextColored(ver_col, "Loaded extensions (%d):", (int)(sizeof(exts) / sizeof(exts[0])));
    ImGui::Separator();
    for (const auto& e : exts) {
        ImGui::TextColored(name_col, "%s", e.name);
        ImGui::SameLine(170.0f);
        ImGui::TextColored(ver_col, "%s", e.version);
        ImGui::SameLine(240.0f);
        ImGui::TextColored(ok_col, "loaded");
    }
}

static void draw_system_tab() {
    const ImVec4 key_col(0.52f, 0.55f, 0.56f, 1.0f);
    const ImVec4 val_col(0.64f, 0.66f, 0.66f, 1.0f);
    const ImVec4 cyan(0.00f, 0.78f, 0.95f, 1.0f);
    auto row = [&](const char* key, const char* val, const ImVec4& vc = ImVec4(0.64f, 0.66f, 0.66f, 1.0f)) {
        ImGui::TextColored(key_col, "%s", key);
        ImGui::SameLine(110.0f);
        ImGui::TextColored(vc, "%s", val);
    };
    const bool complete = state.current_line >= state.lines.size();
    const char* rstate = state.paused ? "paused" : (complete ? "idle" : "streaming");
    char replay_buf[64];
    snprintf(replay_buf, sizeof(replay_buf), "loop | %.1fx | %s", (double)state.speed_multiplier, rstate);

    row("Model:", "google/gemma-4-26b-A4B-it", cyan);
    row("Runtime:", "AILANG Core v0.2.0");
    row("TUI:", "v0.1.0");
    row("Profile:", "default");
    row("Mode:", "autonomous");
    row("Replay:", replay_buf);
}

static void draw_terminal_window() {
    const ImGuiIO& io = ImGui::GetIO();
    const bool phone = io.DisplaySize.x < 640.0f;
    const bool tablet = io.DisplaySize.x >= 640.0f && io.DisplaySize.x < 980.0f;
    const float margin = phone ? 10.0f : 18.0f;
    float width = 0.0f;
    float height = 0.0f;
    float pos_x = margin;
    float pos_y = margin;

    if (phone) {
        width = std::max(280.0f, io.DisplaySize.x - (margin * 2.0f));
        height = std::max(200.0f, std::min(io.DisplaySize.y * 0.38f, io.DisplaySize.y - 280.0f));
        pos_x = margin;
        pos_y = std::max(180.0f, io.DisplaySize.y - height - 64.0f);
    } else if (tablet) {
        width = std::min(720.0f, io.DisplaySize.x - (margin * 2.0f));
        height = std::min(420.0f, std::max(260.0f, io.DisplaySize.y * 0.45f));
        pos_x = std::max(margin, io.DisplaySize.x - width - 24.0f);
        pos_y = std::max(140.0f, io.DisplaySize.y - height - 110.0f);
    } else {
        width = std::min(860.0f, std::max(280.0f, io.DisplaySize.x - (margin * 2.0f)));
        height = std::min(540.0f, std::max(240.0f, io.DisplaySize.y - 260.0f));
        pos_x = std::max(margin, io.DisplaySize.x - width - 48.0f);
        pos_y = std::max(120.0f, io.DisplaySize.y - height - 130.0f);
    }

    ImGui::SetNextWindowSize(ImVec2(width, height), ImGuiCond_FirstUseEver);
    ImGui::SetNextWindowPos(ImVec2(pos_x, pos_y), ImGuiCond_FirstUseEver);

    bool pushed_pulse = false;
    if (state.pulse_kind != PULSE_NONE && state.pulse_timer > 0.0) {
        float max_t = 0.5f;
        if (state.pulse_kind == PULSE_SUCCESS) max_t = 0.4f;
        if (state.pulse_kind == PULSE_PROMPT) max_t = 0.3f;
        float alpha = std::min(1.0f, (float)(state.pulse_timer / (double)max_t));
        ImVec4 pc(0, 0, 0, 0);
        switch (state.pulse_kind) {
            case PULSE_ERROR:   pc = ImVec4(1.0f, 0.22f, 0.26f, alpha * 0.85f); break;
            case PULSE_SUCCESS: pc = ImVec4(0.00f, 0.86f, 0.58f, alpha * 0.65f); break;
            case PULSE_PROMPT:  pc = ImVec4(0.00f, 0.78f, 0.95f, alpha * 0.55f); break;
            default: break;
        }
        ImGui::PushStyleColor(ImGuiCol_Border, pc);
        ImGui::PushStyleVar(ImGuiStyleVar_WindowBorderSize, 2.0f);
        pushed_pulse = true;
    }

    ImGui::Begin("Motoko // TUI session replay");

    float footer_h = ImGui::GetTextLineHeightWithSpacing() + ImGui::GetStyle().ItemSpacing.y + 4.0f;

    if (ImGui::BeginTabBar("console_tabs")) {
        if (ImGui::BeginTabItem("session")) {
            if (ImGui::Button(state.paused ? "resume" : "pause")) {
                state.paused = !state.paused;
            }
            ImGui::SameLine();
            if (ImGui::Button("restart")) {
                state.current_line = 0;
                state.line_timer = 0.0;
                state.loop_pause_timer = 0.0;
                state.paused = false;
            }
            ImGui::SameLine();
            ImGui::SetNextItemWidth(phone ? 100.0f : 150.0f);
            ImGui::SliderFloat("speed", &state.speed_multiplier, 0.25f, 4.0f, "%.1fx");

            if (!state.load_error.empty()) {
                ImGui::TextColored(ImVec4(1.0f, 0.42f, 0.38f, 1.0f), "%s", state.load_error.c_str());
            }

            const int visible_count = (int)std::min(state.current_line, state.lines.size());
            const bool complete = state.current_line >= state.lines.size();
            ImGui::TextColored(
                ImVec4(0.52f, 0.55f, 0.56f, 1.0f),
                "[replay] line %d/%d%s",
                visible_count,
                (int)state.lines.size(),
                complete ? " | state=idle" : " | state=streaming");

            ImGui::Separator();

            ImGui::BeginChild("log-scroll", ImVec2(0.0f, -footer_h), true);
            const float near_bottom_threshold = ImGui::GetTextLineHeightWithSpacing() * 2.0f;
            const bool should_follow =
                ImGui::GetScrollMaxY() <= 0.0f ||
                ImGui::GetScrollY() >= (ImGui::GetScrollMaxY() - near_bottom_threshold);

            draw_log_rows(visible_count);

            if (should_follow) {
                ImGui::SetScrollHereY(1.0f);
            }
            ImGui::EndChild();
            draw_status_strip();
            ImGui::EndTabItem();
        }

        if (ImGui::BeginTabItem("tools")) {
            ImGui::BeginChild("tools-scroll", ImVec2(0.0f, -footer_h), false);
            draw_tools_tab();
            ImGui::EndChild();
            draw_status_strip();
            ImGui::EndTabItem();
        }

        if (ImGui::BeginTabItem("extensions")) {
            ImGui::BeginChild("ext-scroll", ImVec2(0.0f, -footer_h), false);
            draw_extensions_tab();
            ImGui::EndChild();
            draw_status_strip();
            ImGui::EndTabItem();
        }

        if (ImGui::BeginTabItem("system")) {
            ImGui::BeginChild("sys-scroll", ImVec2(0.0f, -footer_h), false);
            draw_system_tab();
            ImGui::EndChild();
            draw_status_strip();
            ImGui::EndTabItem();
        }

        ImGui::EndTabBar();
    }

    ImGui::End();

    if (pushed_pulse) {
        ImGui::PopStyleVar();
        ImGui::PopStyleColor();
    }
}

static void init(void) {
    sg_desc gfx_desc = {};
    gfx_desc.environment = sglue_environment();
    sg_setup(&gfx_desc);
    stm_setup();
    state.last_ticks = stm_now();

    const sg_swapchain swapchain = sglue_swapchain();
    simgui_desc_t imgui_desc = {};
    imgui_desc.color_format = swapchain.color_format;
    imgui_desc.depth_format = swapchain.depth_format;
    imgui_desc.sample_count = swapchain.sample_count;
    imgui_desc.ini_filename = nullptr;
    imgui_desc.write_alpha_channel = true;
    simgui_setup(&imgui_desc);
    configure_imgui_style();
    load_log();

    pass_action.colors[0].load_action = SG_LOADACTION_CLEAR;
    pass_action.colors[0].clear_value = {0.0f, 0.0f, 0.0f, 0.0f};
}

static void frame(void) {
    const uint64_t now = stm_now();
    const double dt = stm_sec(stm_diff(now, state.last_ticks));
    state.last_ticks = now;

    if (!state.paused && !state.lines.empty()) {
        if (state.current_line >= state.lines.size()) {
            state.loop_pause_timer += dt;
            if (state.loop_pause_timer >= 2.4) {
                state.current_line = 0;
                state.line_timer = 0.0;
                state.loop_pause_timer = 0.0;
            }
        } else {
            state.line_timer += dt * (double)state.speed_multiplier;
            double threshold = delay_for_line(state.lines[state.current_line]);
            while (state.line_timer >= threshold && state.current_line < state.lines.size()) {
                state.line_timer -= threshold;
                const std::string& revealed = state.lines[state.current_line];
                if (contains(revealed, "[failed]") || contains(revealed, "[FAIL]") ||
                    contains(revealed, "[ERROR]") || contains(revealed, "FAILED")) {
                    state.pulse_kind = PULSE_ERROR;
                    state.pulse_timer = 0.5;
                } else if (contains(revealed, "[done]") || contains(revealed, "[PASS]") ||
                           contains(revealed, "[OK]")) {
                    state.pulse_kind = PULSE_SUCCESS;
                    state.pulse_timer = 0.4;
                } else if (contains(revealed, "] >") || contains(revealed, "> continue") ||
                           contains(revealed, "> test") || contains(revealed, "> analyze") ||
                           contains(revealed, "> run") || contains(revealed, "> yes")) {
                    state.pulse_kind = PULSE_PROMPT;
                    state.pulse_timer = 0.3;
                }
                state.current_line += 1;
                if (state.current_line < state.lines.size())
                    threshold = delay_for_line(state.lines[state.current_line]);
            }
        }
    }

    if (state.pulse_timer > 0.0) {
        state.pulse_timer -= dt;
        if (state.pulse_timer <= 0.0) {
            state.pulse_timer = 0.0;
            state.pulse_kind = PULSE_NONE;
        }
    }

    simgui_frame_desc_t frame_desc = {};
    frame_desc.width = sapp_width();
    frame_desc.height = sapp_height();
    frame_desc.delta_time = dt;
    frame_desc.dpi_scale = sapp_dpi_scale();
    simgui_new_frame(&frame_desc);

    draw_terminal_window();

    sg_pass pass = {};
    pass.action = pass_action;
    pass.swapchain = sglue_swapchain();
    sg_begin_pass(&pass);
    simgui_render();
    sg_end_pass();
    sg_commit();
}

static void cleanup(void) {
    simgui_shutdown();
    sg_shutdown();
}

static void event(const sapp_event* ev) {
    simgui_handle_event(ev);
    if (ev->type == SAPP_EVENTTYPE_KEY_DOWN && !ImGui::GetIO().WantCaptureKeyboard) {
        switch (ev->key_code) {
            case SAPP_KEYCODE_SPACE:
                state.paused = !state.paused;
                break;
            case SAPP_KEYCODE_R:
                state.current_line = 0;
                state.line_timer = 0.0;
                state.loop_pause_timer = 0.0;
                state.paused = false;
                break;
            case SAPP_KEYCODE_EQUAL:
                state.speed_multiplier = std::min(4.0f, state.speed_multiplier + 0.25f);
                break;
            case SAPP_KEYCODE_MINUS:
                state.speed_multiplier = std::max(0.25f, state.speed_multiplier - 0.25f);
                break;
            default: break;
        }
    }
}

sapp_desc sokol_main(int argc, char* argv[]) {
    (void)argc;
    (void)argv;
    sapp_desc desc = {};
    desc.init_cb = init;
    desc.frame_cb = frame;
    desc.cleanup_cb = cleanup;
    desc.event_cb = event;
    desc.width = 1280;
    desc.height = 720;
    desc.sample_count = 1;
    desc.high_dpi = true;
    desc.alpha = true;
    desc.window_title = "Motoko Agent";
    desc.enable_clipboard = true;
    desc.clipboard_size = 8192;
    desc.html5.canvas_selector = "#canvas";
    desc.html5.canvas_resize = false;
    desc.html5.premultiplied_alpha = false;
    desc.html5.update_document_title = true;
    return desc;
}
