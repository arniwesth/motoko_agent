(* Enumerate.v -- the Rocq counterpart of ../diff/enumerate.lean.tail: every history of length
   0..4 over the same eleven messages, in the same order, one line per history, in the same
   five-field format:

     <message indices>|<hostPending>|<fold accepts>|<fold open ids>|<how many open ids>

   Lean prints these with `#eval` in the proof file. Rocq has no counterpart that prints a
   string, so the lines are computed here, extracted to OCaml (enum.ml), and printed by
   main.ml. The extraction maps Rocq's `string` to OCaml's (ExtrOcamlNativeString); that
   mapping is trusted, as Lean's compiler is trusted for `#eval`. *)
From Stdlib Require Import String List ZArith Bool.
From Stdlib Require Extraction ExtrOcamlBasic ExtrOcamlNativeString.
Require Import PairingModel.
Import ListNotations.
Open Scope string_scope.
Open Scope list_scope.

Definition alphabet : list Msg :=
  [ asst []; asst ["a"]; asst ["a"; "b"]; asst ["b"];
    result "a"; result "b"; result ""; user;
    mkMsg RTool ["b"] "a";          (* 8: violates (H2) *)
    mkMsg RAssistant [] "a";        (* 9: a non-tool message with an id *)
    asst ["a"; ""] ].               (* 10: violates (H1) *)

Fixpoint seqsOfLen (n : nat) : list (list nat) :=
  match n with
  | 0 => [[]]
  | S n => flat_map (fun s => map (fun i => s ++ [i]) (seq 0 (length alphabet))) (seqsOfLen n)
  end.

Definition allSeqs : list (list nat) := flat_map seqsOfLen (seq 0 5).

Definition digit (n : nat) : string :=
  match n with
  | 0 => "0" | 1 => "1" | 2 => "2" | 3 => "3" | 4 => "4"
  | 5 => "5" | 6 => "6" | 7 => "7" | 8 => "8" | _ => "9"
  end.

Definition natStr (n : nat) : string :=
  if Nat.ltb n 10 then digit n else String.append (digit (Nat.div n 10)) (digit (Nat.modulo n 10)).

Definition joinIds (xs : list string) : string := String.concat "," xs.

Definition line (s : list nat) : string :=
  let ms := map (fun i => nth i alphabet (asst [])) s in
  let p := pairing ms in
  let ok := match err p with None => "accept" | Some _ => "refuse" end in
  String.concat "|" [joinIds (map natStr s); joinIds (hostPending ms); ok; joinIds (openIds p);
                     natStr (length (openIds p))].

Definition allLines : list string := map line allSeqs.

Extraction "enum.ml" allLines.
