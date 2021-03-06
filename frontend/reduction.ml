open Knormal;;

let rec reduc k = match k with
    | Let (x, a, b) -> (match a with
        | Let (y, a2, b2) -> reduc (Let (y, a2, (reduc (Let (x, b2, b)))))
        | _ -> Let (x, a, reduc b))
    | App (f, l) -> (* f cannot be a Var so it's not an App nor a Let (see previous part knorm) *)
        let rec reduc_args l = match l with
            | [] -> []
            | t::q -> (reduc t)::(reduc_args q)
        in App (f, reduc_args l)
    | _ -> k
