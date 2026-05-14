#include <algorithm>
#include <cstddef>
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

struct AppState {
    std::vector<std::string> lines;
    std::string load_error;
    std::size_t current_line = 0;
    uint64_t last_ticks = 0;
    double line_timer = 0.0;
    float lines_per_second = 3.0f;
    bool paused = false;
};

static AppState state;
static sg_pass_action pass_action;

static bool contains(const std::string& line, const char* needle) {
    return line.find(needle) != std::string::npos;
}

static ImVec4 color_for_line(const std::string& line) {
    if (contains(line, "[ERROR]") || contains(line, "FAILED")) {
        return ImVec4(1.0f, 0.28f, 0.34f, 1.0f);
    }
    if (contains(line, "[PASS]")) {
        return ImVec4(0.36f, 1.0f, 0.58f, 1.0f);
    }
    if (contains(line, "> executing") || contains(line, "> planning")) {
        return ImVec4(0.38f, 0.86f, 1.0f, 1.0f);
    }
    if (contains(line, "[INFO]")) {
        return ImVec4(0.26f, 0.95f, 0.75f, 1.0f);
    }
    return ImVec4(0.82f, 0.90f, 0.94f, 1.0f);
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
    style.WindowRounding = 6.0f;
    style.ChildRounding = 4.0f;
    style.FrameRounding = 4.0f;
    style.ScrollbarRounding = 4.0f;
    style.GrabRounding = 4.0f;
    style.WindowBorderSize = 1.0f;
    style.FrameBorderSize = 1.0f;
    style.WindowPadding = ImVec2(14.0f, 12.0f);
    style.ItemSpacing = ImVec2(8.0f, 8.0f);

    ImVec4* colors = style.Colors;
    colors[ImGuiCol_WindowBg] = ImVec4(0.015f, 0.025f, 0.030f, 0.88f);
    colors[ImGuiCol_ChildBg] = ImVec4(0.010f, 0.014f, 0.016f, 0.88f);
    colors[ImGuiCol_Border] = ImVec4(0.18f, 0.85f, 0.68f, 0.34f);
    colors[ImGuiCol_TitleBg] = ImVec4(0.010f, 0.030f, 0.034f, 0.96f);
    colors[ImGuiCol_TitleBgActive] = ImVec4(0.020f, 0.120f, 0.105f, 0.96f);
    colors[ImGuiCol_Button] = ImVec4(0.035f, 0.150f, 0.135f, 0.90f);
    colors[ImGuiCol_ButtonHovered] = ImVec4(0.060f, 0.270f, 0.230f, 0.95f);
    colors[ImGuiCol_ButtonActive] = ImVec4(0.050f, 0.360f, 0.300f, 1.00f);
    colors[ImGuiCol_FrameBg] = ImVec4(0.020f, 0.060f, 0.065f, 0.92f);
    colors[ImGuiCol_FrameBgHovered] = ImVec4(0.030f, 0.120f, 0.110f, 0.95f);
    colors[ImGuiCol_FrameBgActive] = ImVec4(0.040f, 0.180f, 0.160f, 1.00f);
    colors[ImGuiCol_SliderGrab] = ImVec4(0.18f, 0.95f, 0.74f, 0.92f);
    colors[ImGuiCol_SliderGrabActive] = ImVec4(0.52f, 1.00f, 0.86f, 1.00f);
}

static void draw_log_rows(int visible_count) {
    const float row_height = ImGui::GetTextLineHeightWithSpacing();
    if (visible_count > 80) {
        ImGuiListClipper clipper;
        clipper.Begin(visible_count, row_height);
        while (clipper.Step()) {
            for (int i = clipper.DisplayStart; i < clipper.DisplayEnd; ++i) {
                const std::string& line = state.lines[(std::size_t)i];
                ImGui::TextColored(color_for_line(line), "%s", line.c_str());
            }
        }
    } else {
        for (int i = 0; i < visible_count; ++i) {
            const std::string& line = state.lines[(std::size_t)i];
            ImGui::TextColored(color_for_line(line), "%s", line.c_str());
        }
    }
}

static void draw_terminal_window() {
    const ImGuiIO& io = ImGui::GetIO();
    const float margin = 18.0f;
    const float max_width = std::max(280.0f, io.DisplaySize.x - (margin * 2.0f));
    const float max_height = std::max(260.0f, io.DisplaySize.y - 156.0f);
    const float width = std::min(860.0f, max_width);
    const float height = std::min(560.0f, max_height);
    const float pos_x = std::max(margin, io.DisplaySize.x - width - 48.0f);
    const float pos_y = std::max(150.0f, io.DisplaySize.y - height - 58.0f);

    ImGui::SetNextWindowSize(ImVec2(width, height), ImGuiCond_FirstUseEver);
    ImGui::SetNextWindowPos(ImVec2(pos_x, pos_y), ImGuiCond_FirstUseEver);

    ImGui::Begin("motoko_agent // live status");

    if (ImGui::Button(state.paused ? "resume" : "pause")) {
        state.paused = !state.paused;
    }
    ImGui::SameLine();
    if (ImGui::Button("restart")) {
        state.current_line = 0;
        state.line_timer = 0.0;
        state.paused = false;
    }
    ImGui::SameLine();
    ImGui::SetNextItemWidth(150.0f);
    ImGui::SliderFloat("speed", &state.lines_per_second, 0.5f, 12.0f, "%.1f lps");

    if (!state.load_error.empty()) {
        ImGui::TextColored(ImVec4(1.0f, 0.42f, 0.38f, 1.0f), "%s", state.load_error.c_str());
    }

    const int visible_count = (int)std::min(state.current_line, state.lines.size());
    const bool complete = state.current_line >= state.lines.size();
    ImGui::TextColored(
        ImVec4(0.55f, 0.70f, 0.76f, 1.0f),
        "lines %d/%d%s",
        visible_count,
        (int)state.lines.size(),
        complete ? " // idle" : "");

    ImGui::Separator();

    ImGui::BeginChild("log-scroll", ImVec2(0.0f, 0.0f), true, ImGuiWindowFlags_HorizontalScrollbar);
    const float near_bottom_threshold = ImGui::GetTextLineHeightWithSpacing() * 2.0f;
    const bool should_follow =
        ImGui::GetScrollMaxY() <= 0.0f ||
        ImGui::GetScrollY() >= (ImGui::GetScrollMaxY() - near_bottom_threshold);

    draw_log_rows(visible_count);

    if (should_follow) {
        ImGui::SetScrollHereY(1.0f);
    }
    ImGui::EndChild();

    ImGui::End();
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

    if (!state.paused && state.current_line < state.lines.size()) {
        state.line_timer += dt * (double)state.lines_per_second;
        while (state.line_timer >= 1.0 && state.current_line < state.lines.size()) {
            state.current_line += 1;
            state.line_timer -= 1.0;
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
