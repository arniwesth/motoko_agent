/-
FrameModel.lean — phase_vocab's message frame, the black box `T4.Env.frame` that the chain
hashes, transcribed so the differential test can instantiate the model and so X-2 can be
stated. Appended after ChainModel.lean (it uses `T4.chainDigestAfter`); check both with
`cat ChainModel.lean FrameModel.lean > /tmp/F.lean && lean /tmp/F.lean`.

SOURCE: src/core/phase_vocab.ail, the snapshot at /home/motoko/trial-043/s/t043-t4-b2/tree:

  frame                    :271-273   `"${label}:${show(Str.length(value))}:${value};"`
  canonical_tool_calls     :286-292
  canonical_message        :294-296   (with `digest_content`, :275-284, as the identity)
  canonical_message_body   :321-323
  canonical_images         :325-331
  canonical_message_frame  :357-359   `"m{${canonical_message_body(m)}${canonical_images(m.images)}}"`

`digest_content` rewrites only `make[1]`..`make[20]`; the model takes it as the identity and
the differential test's alphabet avoids `make[`. `Str.length` is AILANG's rune count, modelled
as `String.length` (Unicode scalar values); equal on valid UTF-8, which is all Lean strings.
Nothing in ChainModel.lean depends on this file: its theorems hold for every frame.
-/

open T4

structure TC where
  id : String
  name : String
  arguments : String

structure Img where
  source : String
  mime : String

structure Message where
  role : String
  content : String
  toolCalls : List TC
  toolCallId : String
  images : List Img

def pframe (label value : String) : String :=
  label ++ ":" ++ toString value.length ++ ":" ++ value ++ ";"

def canonicalToolCalls : List TC → String
  | [] => "tc-end;"
  | c :: rest => "tc{" ++ pframe "id" c.id ++ pframe "name" c.name ++ pframe "args" c.arguments ++ "}" ++ canonicalToolCalls rest

def canonicalImages : List Img → String
  | [] => "im-end;"
  | i :: rest => "im{" ++ pframe "source" i.source ++ pframe "mime" i.mime ++ "}" ++ canonicalImages rest

def canonicalMessageBody (m : Message) : String :=
  pframe "role" m.role ++ pframe "content" m.content ++ pframe "tool_call_id" m.toolCallId
    ++ pframe "tool_calls_len" (toString m.toolCalls.length) ++ canonicalToolCalls m.toolCalls

def canonicalMessageFrame (m : Message) : String :=
  "m{" ++ canonicalMessageBody m ++ canonicalImages m.images ++ "}"

/-- `canonical_message` with `digest_content` as the identity (see the header). -/
def canonicalMessage (m : Message) : String :=
  "m{" ++ pframe "role" m.role ++ pframe "content" m.content ++ pframe "tool_call_id" m.toolCallId
    ++ pframe "tool_calls_len" (toString m.toolCalls.length) ++ canonicalToolCalls m.toolCalls ++ "}"

/-! ## X-2 (an observation, not a reported defect)

`chain_digest_after` hashes `previous ++ frame` with no separator. The frame's own comment
(phase_vocab.ail:351-356) says the length-prefixed framing keeps that concatenation injective
because "a frame is concatenated onto a previous digest" — i.e. onto a fixed-length string.
`chain_digest_over` and `chain_digests_over` take `base : string`, though, and for a base that is
not digest-shaped the step is not injective, FOR EVERY HASH: one frame can be a proper suffix
of another. -/

def x2m1 : Message := { role := "user", content := "m{role:4:user;content:0:", toolCalls := [], toolCallId := "", images := [] }
def x2m2 : Message := { role := "user", content := "", toolCalls := [], toolCallId := "", images := [] }

theorem x2_frames_overlap :
    canonicalMessageFrame x2m1 = "m{role:4:user;content:24:" ++ canonicalMessageFrame x2m2 := by
  simp [canonicalMessageFrame, canonicalMessageBody, canonicalImages, canonicalToolCalls, pframe, x2m1, x2m2]
  decide

theorem x2_messages_differ : canonicalMessageFrame x2m1 ≠ canonicalMessageFrame x2m2 := by
  rw [x2_frames_overlap]
  intro h
  have := congrArg String.length h
  rw [String.length_append] at this
  have : ("m{role:4:user;content:24:" : String).length = 25 := by decide
  omega

/-- The collision: whatever `sha256Hex` is. -/
theorem obs_X2_after_collides (h : String → String) (canon : Message → String) :
    chainDigestAfter { h := h, frame := canonicalMessageFrame, canon := canon } "" x2m1
      = chainDigestAfter { h := h, frame := canonicalMessageFrame, canon := canon }
          "m{role:4:user;content:24:" x2m2 := by
  simp only [chainDigestAfter, x2_frames_overlap]
  rw [String.empty_append]

#print axioms x2_frames_overlap
#print axioms x2_messages_differ
#print axioms obs_X2_after_collides
