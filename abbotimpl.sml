(* Abbot: implementating abstract binding trees (___.abt.impl.sml) *)

structure AbbotImpl =
struct

open Util
open Analysis
open AbbotCore

fun emitimplview (ana: ana) srt = 
let in
    emit ["structure "^Big srt^" =","struct"];
    incr ();
    emitview ana false srt;
    emit ["","val fmap = fn _ => raise Fail \"Unimpl\""];
    decr ();
    emit ["end",""];
    ()
end

(* Symbols and variables: effectively the same implementation *)
fun emitgenstruct issym srt =
let val maybevar = if issym then "" else "Var"
    val typ = srt^maybevar
    val cons = if issym then "Sym" else "Var"
in  emit ["structure "^Big srt^maybevar^" = ","struct"];
    incr();
    emit ["datatype "^typ^" = "^cons^" of string * int"];
    emit ["type t = "^srt^maybevar];
    emit ["val counter = ref 0"];
    emit ["val default = (\"default\", 0)"];
    emit ["fun hash ("^cons^" (_, id)) = id"];
    emit ["fun new"^(if issym then "sym" else "var")^" s"^
          " = "^cons^" (s, (counter := !counter + 1; !counter))"];
    emit ["fun equal ("^cons^" (_, x), "^cons^" (_, y)) = x = y"];
    emit ["fun compare ("^cons^" (_, x), "^cons^" (_, y)) = "^
          "Int.compare (x, y)"];
    emit ["fun toString ("^cons^" (s, id)) = s ^ \"@\" ^ Int.toString id"];
    emit ["fun toUserString ("^cons^" (s, id)) = s"];
    decr();
    emit ["end"];
    (if issym 
     then emit ["type "^srt^" = "^Big srt^"."^srt,""]
     else emit [""]);
    ()
end

val emitsymbolstruct = emitgenstruct true
val emitvariablestruct = emitgenstruct false

(* Actual implementation of sorts *)
(* Naive implementation of locally nameless *)
fun implconstructor srt oper = "Impl_"^Big srt^"_"^oper
fun implbvar srt = "Impl_"^Big srt^"_BoundVar"
fun implfvar srt = "Impl_"^Big srt^"_Var"
fun implfold srt = "Impl_"^Big srt

fun viewconstructor srt oper = "(into_"^srt^" o "^Big srt^"."^oper^")"
fun viewdestructor srt oper = Big srt^"."^oper
fun viewvar srt = Big srt^".Var"

fun emitdatatypeimpl_naive (ana: ana) (pre, srt) =
let
    fun typeofValence ana srt (boundsrts, res) = 
        if null boundsrts then res
        else "("^String.concatWith 
                     " * " (map (fn _ => "string") boundsrts @ [res])^")"

    fun typeofConstructor (ana: ana) srt arity =
        String.concat
            (transFirst
                 (fn () => [])
                 (fn (prelude, arg) => [prelude^arg])
                 (" of ", " * ")
                 (map (typeofValence ana srt) arity))

    fun emitarm ana (pre, NONE) =  
        emit [pre^implbvar srt^" of IntInf.int"]
      | emitarm ana (pre, SOME NONE) = 
(*        emit [pre^implfold srt^" of"^concretesofView ana srt^" "^
              fullview srt] *)
        emit [pre^implfvar srt^" of "^internalvart srt]
      | emitarm ana (pre, SOME (SOME oper)) =
        emit [pre^implconstructor srt oper^
              typeofConstructor ana srt (#arity ana srt oper)]
in 
    emit [pre^" "^srt];
    appFirst 
        (fn _ => raise Fail "Unimplemented: empty sorts")
        (emitarm ana)
        (" = "," | ")
        ((if (#binds ana srt srt) then [NONE, SOME NONE] else []) @
         map (SOME o SOME) (#opers ana srt));
    emit [""];
    ()
end

fun tuple [] = raise Fail "Invariant"
  | tuple [x] = "("^x^")"
  | tuple xs = "("^String.concatWith ", " xs^")" 

(* Format an annotated arity correctly for application to an operator *)
fun operargs [] = ""
  | operargs [ (boundsrts, srt) ] = 
    " "^tuple (map (fn (x,y) => x) (boundsrts @ [srt]))
  | operargs valences = 
    " ("^String.concatWith
             ", " 
             (map (fn (boundsrts, srt) =>
                      tuple (map #1 (boundsrts @ [srt]))) valences)^
    ")"

fun emitcasefunction (ana: ana) srt
                     pre name args incase
                     bvarfn varfn operfn = 
let 
    val knowsRep = isSome bvarfn

    fun annotatevalence n ([], srt) = (n+1, ([], (srt^Int.toString n,srt)))
      | annotatevalence n (boundsrt :: boundsrts, srt) = 
        let val (n', (anno_boundsrts, anno_srt)) =
                annotatevalence (n+1) (boundsrts, srt)
        in (n', ((boundsrt^Int.toString n, srt) :: anno_boundsrts, anno_srt))
        end

    fun annotatearity n [] = []
      | annotatearity n (valence :: valences) = 
        let val (n', anno_valence) = annotatevalence n valence
        in anno_valence :: annotatearity n' valences
        end
       
    val opers = #opers ana srt
    val operarities = 
        map (fn oper => (oper, annotatearity 1 (#arity ana srt oper))) opers
in
    emit [pre^" "^name^" "^args^" = "];
    incr ();
    emit ["case "^(incase srt)^" of"];
    appFirst (fn _ => raise Fail "Invariant")
        (fn (pre, (oper, arity)) => 
            (emit [pre^(if knowsRep 
                        then implconstructor srt oper
                        else viewdestructor srt oper)^
                   operargs arity^" =>"];
             incr (); operfn (oper, arity, srt); decr ())) 
        ("   ", " | ")
        operarities;
    (if not (#binds ana srt srt) then ()
     else if knowsRep
     then (emit [" | "^implfvar srt^" x1 =>"]; 
           incr (); varfn ("x1", srt); decr ();
           emit [" | "^implbvar srt^" n1 =>"]; 
           incr (); (valOf bvarfn) ("n1", srt); decr ())
     else (emit [" | "^viewvar srt^" x1 =>"]; 
           incr (); varfn ("x1", srt); decr ()));
    decr ();
    emit [""];
    ()
end

fun emitcasefunctions (ana: ana) srts
                      namefn args incase
                      bvarfn varfn operfn = 
let in
    appFirst 
        (fn _ => raise Fail "Zero things to emit")
        (fn (pre, srt) => 
            emitcasefunction
                ana srt pre (namefn srt) args incase
                bvarfn varfn operfn)
        ("fun", "and")
        srts
end


(* Emit a mutually-interdependent block of implementations *)
fun emitblockimpl (ana: ana) srts = 
let 
    (* Takes advantage of the fact that 'varin' has to be the same across
     * a block of mutually-defined sorts *)
    val boundinthese = #varin ana (hd srts)
    val dummy = " = fn _ => raise Fail \"Unimpl\""
in
    emit ["(* Implementation of recursive block: "^
          String.concatWith ", " srts ^" *)", ""];
    app (emitimplview ana) srts;
    emit ["(* Naive and minimal implementation *)"];
    emit ["local"];
    incr ();
    appFirst (fn _ => raise Fail "Invariant") (emitdatatypeimpl_naive ana) 
        ("datatype", "and") srts;
    decr ();
    emit ["in"];
    incr ();
    app (fn srt => emit ["type "^srt^" = "^srt]) srts;
    emit [""];

    (* Learn to unbind all the variables that are bound in these sorts *)
    app (fn boundsrt => 
            emitcasefunctions
                ana srts (fn srt => "unbind_"^boundsrt^"_"^srt) 
                ("n newvar x") (fn _ => "x") 
                (SOME (fn (n', srt) => 
                          if boundsrt <> srt then emit ["x"]
                          else emit ["if n = "^n',
                                     "then "^implfvar srt^" newvar",
                                     "else "^implbvar srt^" ("^n'^"-1)"]))
                (fn _ => emit ["x"])
                (fn (oper, arity, srt) => 
                    emit [implconstructor srt oper^
                          operargs 
                              (map (fn (boundsrts, (srtvar, srt)) => 
                                       if #binds ana srt boundsrt
                                       then (boundsrts, 
                                             ("unbind_"^boundsrt^"_"^srt^
                                              " (n+"^
                                              Int.toString (length boundsrts)^
                                              ") newvar "^
                                              srtvar, srt))
                                       else (boundsrts, (srtvar, srt))) 
                                   arity)]))
        boundinthese;

    (* Use unbind to implement projection type -> view *)
    emitcasefunctions
        ana srts (fn srt => "out_"^srt) "x" (fn _ => "x")
        (SOME (fn _ => emit ["raise Fail \"Invariant: exposed bvar\""]))
        (fn (v, srt) => emit [viewvar srt^" "^v])
        (fn (oper, arity, srt) => emit ["raise Match"]);

    emitcasefunctions
        ana srts (fn srt => "into_"^srt) "x" (fn _ => "x") NONE
        (fn _ => emit ["raise Match"])
        (fn (oper, arity, srt) =>
            (case arity of 
                 [] => emit [implconstructor srt oper]
               | _ => emit ["raise Match"]));

    app (fn srt => emit ["val aequiv_"^srt^dummy]) srts;
    app (fn srt => emit ["val toString_"^srt^dummy]) srts;
    app (fn varsrt =>
            app (fn srt => emit ["val free_"^varsrt^"_"^srt^dummy]) srts)
        (#varin ana (hd srts));
    app (fn symsrt =>
            app (fn srt => emit ["val free_"^symsrt^"_"^srt^dummy]) srts)
        (#symin ana (hd srts));
    decr ();
    emit ["end","","(* Derived functions *)"];
    app (fn varsrt =>
            app (fn srt => emit ["val subst_"^varsrt^"_"^srt^dummy]) srts)
        boundinthese;
    emit [""];
    ()
end

(* We want to put this in the abt.impl.sml file in order to have
 * the user structure simply ascribe to an existing signature *)
fun emitfinalimpl (ana: ana) srt = 
let in
    emit ["structure "^Big srt^"Impl =","struct"];
    incr();
    emit ["type t = "^srt];
    app (fn s' => emit ["type "^s'^" = "^s']) (#mutual ana srt);
    app (fn s' => if (#binds ana srt s') 
                  then emit ["type "^s'^"Var = "^internalvart s']
                  else ()) (#mutual ana srt);
    emit ["open "^Big srt];
    emit ["val into = into_"^srt];
    emit ["val out = out_"^srt];
    (if #binds ana srt srt 
     then emit ["structure Var = "^internalvar srt,
                "val Var' = fn x => into (Var x)"]
     else ());
    emit ["val aequiv = aequiv_"^srt];
    emit ["val toString = toString_"^srt];
    app (fn s' => emit ["val subst"^(if srt <> s' then Big s' else "")^
                        " = subst_"^s'^"_"^srt])
        (#varin ana srt);
    app (fn s' => emit ["val free"^(if srt <> s' then (Big s'^"V") else "v")^
                        "ars = subst_"^s'^"_"^srt])
        (#varin ana srt);
    app (fn s' => emit ["val free"^(Big s')^" = free_"^s'^"_"^srt])
        (#symin ana srt);
    app (fn oper => 
            if null (#arity ana srt oper)
            then emit ["val "^oper^"' = into "^viewdestructor srt oper]
            else emit ["val "^oper^"' = fn x => into ("^oper^" x)"])
        (#opers ana srt);
    decr();
    emit ["end",""];
    ()
end

fun doit_impl (ana: ana) = 
let in
    emit ["structure AbbotImpl = ", "struct"];
    incr ();
    emit ["(* All symbols *)"];
    app emitsymbolstruct (#symbs ana);
    emit ["(* All variables *)"];
    app emitvariablestruct 
        (List.filter 
             (fn srt => #binds ana srt srt) 
             (List.concat (#sorts ana)));
    app (emitblockimpl ana) (#sorts ana);
    emit ["(* Rebind structs with full contents *)"];
    app (emitfinalimpl ana) (List.concat (#sorts ana));
    decr ();
    emit ["end"];
    ()
end

end
