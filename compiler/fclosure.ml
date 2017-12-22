open Fknormal;;
open Fsyntax;;
open Printf;;

type t =
(* uncomment those lines when ready to create closures *)
    (*| LetFclosure of (Id.t * Ftype.t) * (Id.l * Ftype.t) * t list*)
    (*| AppC of (Id.l * t list)*)
    | AppD of (Id.t * t list)
    | Unit
    | Bool of bool
    | Int of int
    | Float of float
    | Not of t
    | Neg of t
    | Add of t * t
    | Sub of t * t
    | FNeg of t
    | FAdd of t * t
    | FSub of t * t
    | FMul of t * t
    | FDiv of t * t
    | Eq of t * t
    | LE of t * t
    | IfEq of Id.t * Id.t * t * t
    | IfLE of Id.t * Id.t * t * t
    | IfBool of t * t * t
    | Let of (Id.t * Ftype.t) * t * t
    | Var of Id.t
    | LetRec of fundef * t
    | Tuple of t list
    | LetTuple of (Id.t * Ftype.t) list * t * t
    | Array of t * t
    | Get of t * t
    | Put of t * t * t
and fundef = {
                name : Id.t * Ftype.t;
                args : (Id.t * Ftype.t) list;
                formal_fv : (Id.t * Ftype.t) list;
                body : t
            }

(*type prog = Prog of fundef list * t*)

(* type toplevel = fundef list *)

let rec clos_exp (k:Fknormal.t) :t = match k with
    | Unit -> Unit
    | Bool a -> Bool a
    | Int a ->  Int  a
    | Float a -> Float a
    | Not b -> Not (clos_exp b)
    | Neg b -> Neg (clos_exp b)
    | Sub (a, b) -> Sub (clos_exp a, clos_exp b)
    | Add (a, b) -> Add (clos_exp a, clos_exp b)
    | FAdd (a, b) -> FAdd (clos_exp a, clos_exp b)
    | FNeg b -> FNeg (clos_exp b)
    | FSub (a, b) -> FSub (clos_exp a, clos_exp b)
    | FMul (a, b) -> FMul (clos_exp a, clos_exp b)
    | FDiv (a, b) -> FDiv (clos_exp a, clos_exp b)
    | Eq (a, b) -> Eq (clos_exp a, clos_exp b)
    | LE (a, b) -> LE (clos_exp a, clos_exp b)
    | Var a -> Var a
    | IfEq (x, y, b, c) -> IfEq (x, y, clos_exp b, clos_exp c)
    | IfLE (x, y, b, c) -> IfLE (x, y, clos_exp b, clos_exp c)
    (* |IfBool (a, b, c) -> IfBool (clos_exp a, clos_exp b, clos_exp c) *)
    | Tuple a -> Tuple (List.map clos_exp a)
    (* |LetTuple (a, b, c) -> LetTuple (clos_exp a, clos_exp b, clos_exp c) *)
    | Array (a, b) -> Array (clos_exp a, clos_exp b)
    | Get (a, b) -> Get (clos_exp a, clos_exp b)
    | Put (a, b, c) -> Put (clos_exp a, clos_exp b, clos_exp c)
    (* TODO remove let later *)
    | Let (x, a, b) -> Let (x, clos_exp a, clos_exp b)
    | LetRec (fundef, a) -> LetRec ({name = fundef.name; args = fundef.args; formal_fv = []; body = (clos_exp fundef.body)}, (clos_exp a))
    | App (f, l) -> (match f with
                        | (Var id) -> AppD ("_"^id, List.map clos_exp l)
                        | _ -> failwith "matchfailure App")
    | _-> failwith "match not exhaustive in clos_exp fclosure.ml"
    (*/tmp*)

(* Nested letrec have not been unnested yet (in reduction) *)
(*
let rec clos_aux (k:Fknormal.t) :(Fknormal.fundef option * Fknormal.t) = match k with
(*concat newbody obtained with clos aux*)
    | Let (x, a, b) ->
        let (extract, newbody) = (clos_aux b) in (extract, Let (x, a, newbody))
            (* (match newbody with
                | None -> (None, Let (x, a, newbody))
                | Some fundef -> (extract, Let (x, a, newbody))) *)
    | LetRec (fundef, t) ->
        (* while extract = Some
        let (extract, following_body) = clos_aux t in
        (Some fundef, following_body)*)
        let (fname, fargs, fbody) = (fundef.name, fundef.args, fundef.body) in
        let (extract, newfbody) = (clos_aux fbody) in
            (match extract with
            | None ->
                print_string "None\n";
                print_string (sprintf "%s\n" (let (n, _) = fundef.name in n));
                (Some fundef, LetRec ({name = fname; args = fargs; body = newfbody}, clos t)) (* we can put newfbody or fbody here*)
            | Some extract ->
                let (ename, eargs, ebody) = (extract.name, extract.args, extract.body) in
                    (* the first clos_aux will unnest ebody
                    the second will continue unnesting the let recs that are on the same level as extract
                    So this is both a depth and width modification at the same time *)
                    let (retextract, retnewbody) =
                        clos_aux (LetRec ({name = ename;
                                          args = eargs;
                                          body = ebody},
                                          clos (LetRec ({name = fname;
                                                        args = fargs;
                                                        body = newfbody},
                                                        t)
                                                    )
                                          )
                                 )
                    in (retextract, retnewbody))
    | _ -> (None, k)

and clos (k:Fknormal.t) =
    let (_, a) = (clos_aux k) in a *)

(*let clos_out k = clos_exp (clos k)*)




(* (*THE BEST VERSION SO FAR*)
let rec the_savage_phi (fb:Fknormal.t) : (Fknormal.fundef option * Fknormal.t)  =
        match fb with
        |Let(a,b,c) -> (
                        let recbody, newin = the_savage_phi c in
                        match recbody with
                        |None -> (None, Let(a, b, newin))
                        |Some fbody -> (Some fbody, Let(a,b, newin))
                        )
        |LetRec(fbody, recin) -> (Some fbody, recin)
        |_ -> (None, fb)

and the_cunning_psi (ast : Fknormal.t) : Fknormal.t =
    match ast with
    |LetRec(fd, een) -> (
                        let recbody, newin = the_savage_phi fd.body in
                        match recbody with
                        |None -> LetRec(chi fd, een)
                        |Some fbody -> the_cunning_psi ( LetRec(chi fbody, the_cunning_psi (LetRec({name=fd.name; args=fd.args; body=newin}, een))))
                        )
    |Let(a,b,c) -> Let(a, the_cunning_psi b, the_cunning_psi c)
    |_ -> ast
*)

let rec the_savage_phi (fb:Fknormal.t) : (Fknormal.fundef option * Fknormal.t)  =
        match fb with
        |Let(a,b,c) -> (
                        let recbody, newin = the_savage_phi c in
                        match recbody with
                        |None -> (None,  Let(a, b, newin))
                        |Some fbody -> (Some fbody, Let(a,b, newin))
                        )
        |LetRec(fbody, recin) -> (Some fbody, recin)
        |_ -> (None, fb)

and the_cunning_psi (ast : Fknormal.t) : Fknormal.t =
    match ast with
    |LetRec(fd, een) -> (
                        let recbody, newin = the_savage_phi fd.body in
                        match recbody with
                        |None -> LetRec(fd, een)
                        |Some fbody -> the_cunning_psi ( LetRec(fbody, the_cunning_psi (LetRec({name=fd.name; args=fd.args; body=newin}, een))))
                        )
    |Let(a,b,c) -> Let(a, the_cunning_psi b, the_cunning_psi c)
    |_ -> ast


(*and chi fd = fd*)

let clos_out k = clos_exp (the_cunning_psi k)
(* We now consider that there are no free variable inside our nested letrecs *)
    (* | LetRec (fundef, t) ->
        let (fname, fargs, fbody) = (fundef.name, fundef.args, fundef.body) in
            (match fbody with
            | LetRec (fundef2, t2) ->
                let (newfundef : Fknormal.fundef) = {name = fname; args = fargs; body = t2} in
                (match (clos (LetRec (fundef2, Unit))) with
                | LetRec (f, _) ->
                    let newfundef2 = {name = f.name; args = f.args; formal_fv = []; body = (clos_exp t2)} in
                    LetRec (newfundef2, clos (LetRec (newfundef, t)))
                | _ -> failwith "matchfailure Neg")
            | _ -> failwith "matchfailure Neg") *)

            (* | Let (x, a, b) -> *)

    (* For now we assume there is no free variable so a let rec can't be after a let for now ? *)
    (* | Let (x, a, b) -> (* lets have already been unnested *)
        (match a with
        | LetRec (f, c) ->
            let (iden, typ) = f.name in
            LetRec ({name = ("_"^iden, typ); args = f.args; formal_fv = []; body = (clos_exp f.body)}, Let (x, clos c, clos b))
        | _ -> Let (x, clos a, clos b)) (* TODO we assume we can't have let ... in let ... let rec ... in in*)
    | App (f, l) -> (match f with
                        | (Var id) -> AppD ("_"^id, List.map clos_exp l)
                        | _ -> failwith "matchfailure Neg")
    | _ -> clos_exp k *)

    (* | App (f, l) ->
        let rec clos_args l = match l with
            | [] -> []
            | t::q -> (clos t)::(clos_args q)
        in AppD (f, clos_args l) *)


(*
let rec clos_toplevel k = match k with
    | -> Toplevel (clos l) *)

let rec clos_to_string (c:t) : string =
    match c with
  | Unit -> "()"
  | Bool b -> if b then "true" else "false"
  | Int i -> string_of_int i
  | Float f -> sprintf "%.2f" f
  | Not e -> sprintf "(not %s)" (clos_to_string e)
  | Neg e -> sprintf "(- %s)" (clos_to_string e)
  | Add (e1, e2) -> sprintf "(%s + %s)" (clos_to_string e1) (clos_to_string e2)
  | Sub (e1, e2) -> sprintf "(%s - %s)" (clos_to_string e1) (clos_to_string e2)
  | FNeg e -> sprintf "(-. %s)" (clos_to_string e)
  | FAdd (e1, e2) -> sprintf "(%s +. %s)" (clos_to_string e1) (clos_to_string e2)
  | FSub (e1, e2) -> sprintf "(%s -. %s)" (clos_to_string e1) (clos_to_string e2)
  | FMul (e1, e2) -> sprintf "(%s *. %s)" (clos_to_string e1) (clos_to_string e2)
  | FDiv (e1, e2) -> sprintf "(%s /. %s)" (clos_to_string e1) (clos_to_string e2)
  | Eq (e1, e2) -> sprintf "(%s = %s)" (clos_to_string e1) (clos_to_string e2)
  | LE (e1, e2) -> sprintf "(%s <= %s)" (clos_to_string e1) (clos_to_string e2)
  | IfEq (x, y, e2, e3) ->
          sprintf "(if %s=%s then %s else %s)" (Id.to_string x) (Id.to_string y) (clos_to_string e2) (clos_to_string e3)
  | IfLE (x, y, e2, e3) ->
          sprintf "(if %s <= %s then %s else %s)" (Id.to_string x) (Id.to_string y) (clos_to_string e2) (clos_to_string e3)
  | Let ((id,t), e1, e2) ->
          sprintf "(let %s = %s in %s)" (Id.to_string id) (clos_to_string e1) (clos_to_string e2)
  | Var id -> Id.to_string id
  | AppD (e1, le2) -> sprintf "(%s %s)" (Id.to_string e1) (infix_to_string clos_to_string le2 " ")
  | LetRec (fd, e) ->
          sprintf "(let rec %s %s = %s in %s)"
          (let (x, _) = fd.name in (Id.to_string x))
          (infix_to_string (fun (x,_) -> (Id.to_string x)) fd.args " ")
          (clos_to_string fd.body)
          (clos_to_string e)
  | LetTuple (l, e1, e2)->
          sprintf "(let (%s) = %s in %s)"
          (infix_to_string (fun (x, _) -> Id.to_string x) l ", ")
          (clos_to_string e1)
          (clos_to_string e2)
  | Get(e1, e2) -> sprintf "%s.(%s)" (clos_to_string e1) (clos_to_string e2)
  | Put(e1, e2, e3) -> sprintf "(%s.(%s) <- %s)"
                 (clos_to_string e1) (clos_to_string e2) (clos_to_string e3)
  | Tuple(l) -> sprintf "(%s)" (infix_to_string clos_to_string l ", ")
  | Array(e1,e2) -> sprintf "(Array.create %s %s)"
       (clos_to_string e1) (clos_to_string e2)
   | _-> "NotYetImplemented"
