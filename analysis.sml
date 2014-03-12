structure Analysis =
struct
  
   type ana = {
       sorts: string list list,
       issrt: string -> bool,
       symbs: string list,
       issym: string -> bool,
       opers: string -> string list,
       arity: string -> string -> (string list * string) list,
       binds: string -> string -> bool,
       varin: string -> string list,
       symin: string -> string list,
       mutual: string -> string list,
       mutualwith: string -> string -> bool
   }

   val systemf: ana = {
       sorts = [["tp"], ["exp"]],
       issrt = (fn "exp" => true | "tp" => true | _ => false),
       symbs = [],
       issym = (fn _ => false),
       opers = (fn "exp" => ["Lam","App", "TLam",  "TApp"]
               | "tp" => ["All", "Arr"]
               | _ => raise Fail ""),
       arity = (fn "exp" =>
                 (fn "TLam" => [(["tp"], "exp")]
                 | "Lam" => [([], "tp"), (["exp"], "exp")]
                 | "TApp" => [([], "exp"), ([], "tp")]
                 | "App" => [([], "exp"), ([], "exp")])
               | "tp" =>
                 (fn "All" => [(["tp"], "tp")]
                 | "Arr" => [([], "tp"), ([], "tp")])),
       binds = (fn "tp" => (fn s => s = "tp")
               | "exp" => (fn "exp" => true | s => s = "tp")),
       varin = (fn "tp" => ["tp"]
               | "exp" => ["tp", "exp"]
               | _ => raise Fail ""),
       symin = (fn _ => []),
       mutual = (fn s => [s]),
       mutualwith = (fn s => fn t => s = t)
   }
                          
   val godel: ana = {
       sorts = [["tp"], ["exp"]],
       issrt = (fn "exp" => true | "tp" => true | _ => false),
       symbs = [],
       issym = (fn _ => false),
       opers = (fn "exp" => ["Z", "S", "Rec", "Lam", "Ap"]
               | "tp" =>  ["Nat", "Arr"]
               | _ => raise Fail ""),
       arity = (fn "exp" => 
                 (fn "Z" => []
                 | "S" => [([], "exp")]
                 | "Rec" => [([], "exp"), ([], "exp"), (["exp", "exp"], "exp")]
                 | "Lam" => [([], "tp"), (["exp"], "exp")]
                 | "Ap" => [([], "exp"), ([], "exp")]
                 | _ => raise Fail "")
               | "tp" =>
                 (fn "Nat" => []
                 | "Arr" => [([], "tp"), ([], "tp")]
                 | _ => raise Fail "")
               | _ => raise Fail ""),
       varin = (fn "exp" => ["exp"] | _ => []),
       symin = (fn _ => []),
       binds = (fn s => (fn "exp" => s = "exp" | _ => false)),
       mutual = (fn s => [s]),
       mutualwith = (fn s => fn t => s = t)
   }

   val minalgol: ana = {
       sorts = [["side"], ["tp"], ["exp", "cmd"]],
       issrt = (fn s => List.exists (List.exists (fn t => s = t)) 
                                     [["side"], ["tp"], ["exp", "cmd"]]),
       symbs = ["assign"],
       issym = (fn "assign" => true | _ => false),
       opers = (fn "side" => ["L", "R"] 
               | "tp" => ["Nat", "Parr", "Unit", "Prod", "Void", "Sum", "Cmd"]
               | "exp" => ["Z", "S", "Ifz", "Lam", "Ap", "Let", "Fix",
                           "Triv", "Pair", "Pr", "Abort", "In", "Case", "Cmd"]
               | "cmd" => ["Ret", "Bnd", "Dcl", "Get", "Set"]
               | _ => raise Fail ""),
       arity = (fn "side" =>
                 (fn "L" => []
                 | "R" => [])
               | "tp" => 
                 (fn "Nat" => []
                 | "Parr" => [([], "tp"), ([], "tp")]
                 | "Unit" => []
                 | "Prod" => [([], "tp"), ([], "tp")]
                 | "Void" => []
                 | "Sum" => [([], "tp"), ([], "tp")]
                 | "Cmd" => [([], "tp")])
               | "exp" =>
                 (fn "Z" => []
                 | "S" => [([], "exp")]
                 | "Ifz" => [([], "exp"), ([], "exp"), (["exp"], "exp")]
                 | "Lam" => [([], "tp"), (["exp"], "exp")]
                 | "Ap" => [([], "exp"), ([], "exp")]
                 | "Let" => [([], "exp"), (["exp"], "exp")]
                 | "Fix" => [([], "tp"), (["exp"], "exp")]
                 | "Triv" => []
                 | "Pair" => [([], "exp"), ([], "exp")]
                 | "Pr" => [([], "side"), ([], "exp")]
                 | "Abort" => [([], "tp"), ([], "exp")]
                 | "In" => [([], "tp"), ([], "tp"), ([], "side"), ([], "exp")]
                 | "Case" => [([], "exp"), (["exp"], "exp"), (["exp"], "exp")]  
                 | "Cmd" => [([], "cmd")])
               | "cmd" => 
                 (fn "Bnd" => [([], "exp"), (["exp"], "cmd")]
                 | "Ret" => [([], "exp")]
                 | "Dcl" => [([], "exp"), (["assign"], "cmd")]
                 | "Get" => [([], "assign")]
                 | "Set" => [([], "assign"), ([], "exp")])
               | _ => raise Fail ""),
       binds = (fn "cmd" => 
                 (fn "exp" => true
                 | _ => false)
               | "exp" => 
                 (fn "exp" => true
                 | _ => false)
               | _ => (fn _ => false)), 
       varin = (fn "exp" => ["exp"] | "cmd" => ["exp"] | _ => []),
       symin = (fn "exp" => ["assign"] | "cmd" => ["assign"] | _ => []),
       mutual = (fn "exp" => ["exp", "cmd"]
                 | "cmd" => ["exp", "cmd"]
                 | s => [s]),
       mutualwith = (fn s =>
                        (fn "exp" => s = "exp" orelse s = "cmd"
                        | "cmd" => s = "exp" orelse s = "cmd"
                        | t => s = t))
   }
                    

       

(* val pcf_pattern = {
       typs = [["tp"], ["side"], ["pat"], ["exp", "rules", "rule"]],
       cons = (fn "tp" => ["nat", "parr", "unit", "pair", "zero", "sum"]
              | "pat" => ["wild", "var", "z", "s", "triv", "pair", "in"]
              | "exp" => ["fix", "z", "s", "ifz", "lam", "app",
                          "triv", "pair", "pr",
                          "abort", "in", "case", 
                          "match"]
              | "rules" => ["rules"]
              | "rule" => ["rule"]),
       (* arity = (fn "tp" =>
                   (fn "nat" =>
                   | "parr" =>
                   | "unit" =>
                   | "pair" =>
                   | "zero" =>
                   | "sum" => *)
   } *)

end
