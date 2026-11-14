/-
Sha256.lean — an executable SHA-256 (FIPS 180-4), Lean 4 core only, for the differential test
ONLY. It instantiates `T4.Env.h` so the model's digests can be compared byte for byte with the
real `std/crypto.sha256Hex`. No theorem uses it: the theorems in ChainModel.lean hold for every
hash, and the `bug_` ones for every injective one. Appended after ChainModel.lean by
../diff/run_diff.sh. Self-check: `sha256Hex "abc"` must be
ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad (FIPS 180-4 example).
-/

namespace Sha256

def K : Array UInt32 := #[
  0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
  0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
  0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
  0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
  0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
  0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
  0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
  0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2 ]

def H0 : Array UInt32 := #[
  0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a, 0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19 ]

def rotr (x n : UInt32) : UInt32 := (x >>> n) ||| (x <<< (32 - n))

def pad (msg : ByteArray) : ByteArray := Id.run do
  let bitLen : UInt64 := msg.size.toUInt64 * 8
  let mut m := msg.push 0x80
  while m.size % 64 != 56 do
    m := m.push 0
  for i in [0:8] do
    m := m.push (bitLen >>> (8 * (7 - i)).toUInt64).toUInt8
  return m

def compress (hs : Array UInt32) (m : ByteArray) (off : Nat) : Array UInt32 := Id.run do
  let mut w : Array UInt32 := #[]
  for i in [0:16] do
    let b := fun j => (m.get! (off + 4 * i + j)).toUInt32
    w := w.push ((b 0 <<< 24) ||| (b 1 <<< 16) ||| (b 2 <<< 8) ||| b 3)
  for i in [16:64] do
    let s0 := rotr w[i-15]! 7 ^^^ rotr w[i-15]! 18 ^^^ (w[i-15]! >>> 3)
    let s1 := rotr w[i-2]! 17 ^^^ rotr w[i-2]! 19 ^^^ (w[i-2]! >>> 10)
    w := w.push (w[i-16]! + s0 + w[i-7]! + s1)
  let mut a := hs[0]!
  let mut b := hs[1]!
  let mut c := hs[2]!
  let mut d := hs[3]!
  let mut e := hs[4]!
  let mut f := hs[5]!
  let mut g := hs[6]!
  let mut h := hs[7]!
  for i in [0:64] do
    let S1 := rotr e 6 ^^^ rotr e 11 ^^^ rotr e 25
    let ch := (e &&& f) ^^^ ((~~~e) &&& g)
    let t1 := h + S1 + ch + K[i]! + w[i]!
    let S0 := rotr a 2 ^^^ rotr a 13 ^^^ rotr a 22
    let maj := (a &&& b) ^^^ (a &&& c) ^^^ (b &&& c)
    let t2 := S0 + maj
    h := g
    g := f
    f := e
    e := d + t1
    d := c
    c := b
    b := a
    a := t1 + t2
  return #[hs[0]! + a, hs[1]! + b, hs[2]! + c, hs[3]! + d,
           hs[4]! + e, hs[5]! + f, hs[6]! + g, hs[7]! + h]

def hexDigit (n : UInt32) : Char := "0123456789abcdef".toList[n.toNat]!

def hex32 (x : UInt32) : String :=
  String.ofList ((List.range 8).map (fun i => hexDigit ((x >>> (28 - 4 * i).toUInt32) &&& 0xf)))

def sha256Hex (s : String) : String := Id.run do
  let m := pad s.toUTF8
  let mut hs := H0
  for blk in [0:m.size / 64] do
    hs := compress hs m (64 * blk)
  return String.join (hs.toList.map hex32)

end Sha256
