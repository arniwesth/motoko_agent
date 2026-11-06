(* PairingModel.v -- a port of ../PairingModel.lean to Rocq, written to compare the two provers
   on the same model (NOTE-001-rocq-compared-2026-11-03.md). Not a second model of the code:
   same definitions, same theorems, in the same order, for Rocq 9.3.0 with its Stdlib only.

   The Lean file is the one that counts. Where the two differ, the difference is Rocq's:
     * Stdlib records have no `{ acc with ... }`, so each update in `pairStep` restates all
       four fields by position.
     * `0 <? n` is spelled `Nat.ltb 0 n`: with `string_scope` open, `<?` is string comparison.
     * Lean's `decide` on a closed goal is `reflexivity` here; both are kernel reduction.

   `rocq compile -Q . "" PairingModel.v` checks it and prints `Print Assumptions` for the
   same eight theorems `#print axioms` covers in the Lean file. *)

From Stdlib Require Import String List ZArith Bool.
Import ListNotations.
Open Scope string_scope.
Open Scope list_scope.

Inductive Role := RSystem | RUser | RAssistant | RTool.

Record Msg := mkMsg { role : Role; calls : list string; callId : string }.

(** * The AILANG side: journal.ail *)

Fixpoint containsString (xs : list string) (t : string) : bool :=
  match xs with
  | [] => false
  | x :: rest => if String.eqb x t then true else containsString rest t
  end.

Fixpoint withoutString (xs : list string) (t : string) : list string :=
  match xs with
  | [] => []
  | x :: rest => if String.eqb x t then withoutString rest t else x :: withoutString rest t
  end.

Record PairAcc := mkAcc { err : option Z; openIds : list string; curIds : list string; curSeq : Z }.

(* `pair_step`, branch for branch. Rocq has no `{ acc with ... }`, so each update is spelled out. *)
Definition pairStep (acc : PairAcc) (h : nat * Msg) : PairAcc :=
  match err acc with
  | Some _ => acc
  | None =>
    match role (snd h) with
    | RTool =>
      if containsString (curIds acc) (callId (snd h))
      then mkAcc (err acc) (withoutString (openIds acc) (callId (snd h))) (curIds acc) (curSeq acc)
      else mkAcc (Some (Z.of_nat (fst h))) (openIds acc) (curIds acc) (curSeq acc)
    | _ =>
      if Nat.ltb 0 (length (openIds acc)) then mkAcc (Some (curSeq acc)) (openIds acc) (curIds acc) (curSeq acc)
      else if Nat.ltb 0 (length (calls (snd h)))
      then mkAcc (err acc) (calls (snd h)) (calls (snd h)) (Z.of_nat (fst h))
      else acc
    end
  end.

Definition pair0 : PairAcc := mkAcc None [] [] (-1)%Z.

Fixpoint tag (n : nat) (ms : list Msg) : list (nat * Msg) :=
  match ms with
  | [] => []
  | m :: ms => (n, m) :: tag (S n) ms
  end.

Definition pairing (ms : list Msg) : PairAcc := fold_left pairStep (tag 0 ms) pair0.

(** * The TypeScript side: session-journal.ts *)

Definition updatePending (opn : list string) (m : Msg) : list string :=
  if Nat.ltb 0 (length (calls m)) then filter (fun id => negb (String.eqb id "")) (calls m)
  else if negb (String.eqb (callId m) "") then filter (fun id => negb (String.eqb id (callId m))) opn
  else opn.

Definition hostPending (ms : list Msg) : list string := fold_left updatePending ms [].

(** * Fixtures *)

Definition asst (ids : list string) : Msg := mkMsg RAssistant ids "".
Definition result (id : string) : Msg := mkMsg RTool [] id.
Definition user : Msg := mkMsg RUser [] "".

(** * 1. Two shapes the fold's pairing check admits *)

Theorem admits_duplicate_result :
  err (pairing [asst ["a"]; result "a"; result "a"]) = None.
Proof. reflexivity. Qed.

Theorem admits_result_after_user :
  err (pairing [asst ["a"]; result "a"; user; result "a"]) = None.
Proof. reflexivity. Qed.

Theorem refuses_unanswered_call_before_user :
  err (pairing [asst ["a"; "b"]; result "a"; user]) = Some 0%Z.
Proof. reflexivity. Qed.

Theorem refuses_result_for_unmade_call :
  err (pairing [asst ["a"]; result "b"]) = Some 1%Z.
Proof. reflexivity. Qed.

Theorem trailing_call_is_dangling :
  err (pairing [asst ["a"; "b"]; result "a"]) = None /\
  openIds (pairing [asst ["a"; "b"]; result "a"]) = ["b"] /\
  hostPending [asst ["a"; "b"]; result "a"] = ["b"].
Proof. repeat split. Qed.

(** * 2. Host twin = fold, under (H1) and (H2) *)

Lemma err_sticky : forall xs acc r,
  err acc = Some r -> fold_left pairStep xs acc = acc.
Proof.
  induction xs as [|x xs IH]; intros acc r H; simpl; [reflexivity|].
  assert (pairStep acc x = acc) as -> by (unfold pairStep; rewrite H; reflexivity).
  exact (IH acc r H).
Qed.

Lemma containsString_mem : forall xs t, containsString xs t = true -> In t xs.
Proof.
  induction xs as [|x xs IH]; simpl; intros t H; [discriminate|].
  destruct (String.eqb x t) eqn:E.
  - left. apply String.eqb_eq. exact E.
  - right. exact (IH t H).
Qed.

Lemma filter_eq_without : forall xs t,
  filter (fun id => negb (String.eqb id t)) xs = withoutString xs t.
Proof.
  induction xs as [|x xs IH]; simpl; intros t; [reflexivity|].
  destruct (String.eqb x t); simpl; rewrite IH; reflexivity.
Qed.

Lemma filter_nonempty_id : forall xs,
  (forall c, In c xs -> c <> "") -> filter (fun id => negb (String.eqb id "")) xs = xs.
Proof.
  induction xs as [|x xs IH]; simpl; intros H; [reflexivity|].
  destruct (String.eqb x "") eqn:E.
  - apply String.eqb_eq in E. exfalso. exact (H x (or_introl eq_refl) E).
  - simpl. rewrite IH; [reflexivity|]. intros c Hc. exact (H c (or_intror Hc)).
Qed.

Lemma step_agrees : forall acc x opn,
  err acc = None -> opn = openIds acc ->
  (forall c, In c (curIds acc) -> c <> "") ->
  (forall c, In c (calls (snd x)) -> c <> "") ->
  (role (snd x) = RTool -> calls (snd x) = []) ->
  err (pairStep acc x) = None ->
  updatePending opn (snd x) = openIds (pairStep acc x) /\
  (forall c, In c (curIds (pairStep acc x)) -> c <> "").
Proof.
  intros acc [n [r cs cid]] opn Hacc Hopen Hcur H1 H2 Hstep; subst opn; simpl in *.
  unfold pairStep in *; rewrite Hacc in *; simpl in *.
  destruct r.
  4: {
    specialize (H2 eq_refl); subst cs.
    destruct (containsString (curIds acc) cid) eqn:Hin; simpl in *; [|discriminate].
    pose proof (Hcur cid (containsString_mem _ _ Hin)) as Hne.
    unfold updatePending; simpl.
    destruct (String.eqb cid "") eqn:E; [apply String.eqb_eq in E; contradiction|].
    split; [apply filter_eq_without | exact Hcur].
  }
  all: destruct (Nat.ltb 0 (length (openIds acc))) eqn:Ho; simpl in *; [discriminate|].
  all: unfold updatePending; simpl.
  all: destruct (Nat.ltb 0 (length cs)) eqn:Hc; simpl.
  all: try (split; [apply filter_nonempty_id; exact H1 | exact H1]).
  all: destruct (openIds acc); [|discriminate].
  all: destruct (negb (String.eqb cid "")); split; try reflexivity; exact Hcur.
Qed.

Lemma agrees_fold : forall xs acc opn,
  (forall x, In x xs -> forall c, In c (calls (snd x)) -> c <> "") ->
  (forall x, In x xs -> role (snd x) = RTool -> calls (snd x) = []) ->
  err acc = None -> opn = openIds acc ->
  (forall c, In c (curIds acc) -> c <> "") ->
  err (fold_left pairStep xs acc) = None ->
  fold_left updatePending (map snd xs) opn = openIds (fold_left pairStep xs acc).
Proof.
  induction xs as [|x xs IH]; intros acc opn H1 H2 Hacc Hopen Hcur Hok; simpl in *.
  - exact Hopen.
  - destruct (err (pairStep acc x)) as [r|] eqn:Hs.
    + rewrite (err_sticky xs _ r Hs), Hs in Hok. discriminate.
    + destruct (step_agrees acc x opn Hacc Hopen Hcur (H1 x (or_introl eq_refl))
                  (H2 x (or_introl eq_refl)) Hs) as [Heq Hcur'].
      apply IH; [ intros y Hy; apply H1; right; exact Hy
                | intros y Hy; apply H2; right; exact Hy
                | exact Hs | exact Heq | exact Hcur' | exact Hok ].
Qed.

Lemma tag_map : forall ms n, map snd (tag n ms) = ms.
Proof. induction ms as [|m ms IH]; simpl; intros n; [reflexivity|]. rewrite IH. reflexivity. Qed.

Lemma tag_mem : forall ms n x, In x (tag n ms) -> In (snd x) ms.
Proof.
  induction ms as [|m ms IH]; simpl; intros n x H; [contradiction|].
  destruct H as [H|H]; [subst x; left; reflexivity | right; exact (IH _ _ H)].
Qed.

Theorem host_twin_agrees : forall ms,
  (forall m, In m ms -> forall c, In c (calls m) -> c <> "") ->
  (forall m, In m ms -> role m = RTool -> calls m = []) ->
  err (pairing ms) = None ->
  hostPending ms = openIds (pairing ms).
Proof.
  intros ms H1 H2 Hok. unfold hostPending, pairing in *.
  pose proof (agrees_fold (tag 0 ms) pair0 []
    (fun x hx => H1 (snd x) (tag_mem _ _ _ hx)) (fun x hx => H2 (snd x) (tag_mem _ _ _ hx))
    eq_refl eq_refl (fun c hc => match hc with end) Hok) as H.
  rewrite tag_map in H. exact H.
Qed.

(** * 3. Without (H2), or (H1) in the trailing batch, the two sides disagree *)

Theorem twin_disagrees_without_h2 :
  let ms := [asst ["a"]; mkMsg RTool ["b"] "a"] in
  err (pairing ms) = None /\ openIds (pairing ms) = [] /\ hostPending ms = ["b"].
Proof. cbv zeta. repeat split. Qed.

Theorem h1_not_free_in_trailing_batch :
  err (pairing [asst ["a"; ""]; result "a"]) = None /\
  openIds (pairing [asst ["a"; ""]; result "a"]) = [""] /\
  hostPending [asst ["a"; ""]; result "a"] = [].
Proof. repeat split. Qed.

Print Assumptions admits_duplicate_result.
Print Assumptions admits_result_after_user.
Print Assumptions twin_disagrees_without_h2.
Print Assumptions h1_not_free_in_trailing_batch.
Print Assumptions host_twin_agrees.
Print Assumptions refuses_unanswered_call_before_user.
Print Assumptions refuses_result_for_unmade_call.
Print Assumptions trailing_call_is_dangling.
