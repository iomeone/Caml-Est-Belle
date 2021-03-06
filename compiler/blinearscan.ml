(** This module is to do linearscan register allocation *)
open Bliveinterval;;
open Bsyntax;;
open Printf;;

(* f_Ri_load_store*)

let active = ref [("a","b",1);]
let spill = ref []
let free_reg_pool = ["R0";"R1";"R2";"R3";"R4";"R5";"R6";"R7";"R8";"R9";"R10";"R12";]
(*let free_reg_pool = ref["R0";"R1";"R2"]*)
let free_reg = ref free_reg_pool
let spill_counter = ref 0


let trd t = let a,b,c = t in c
let snd_ning t = let a,b,c = t in b
let fst_ning t = let a,b,c = t in a


(*let rec print_active l =
	(*Printf.fprintf stdout "start list\n";*)
	(match l with
	|t::q -> let str = ref sprintf "%s %s %i\n" (Id.to_string (fst_ning t)) (snd_ning t) (trd t) in ; print_active q
	| [] -> ());
	(*Printf.fprintf stdout "end list\n"*)*)
	
	
	
let rec print_spill l =
	Printf.fprintf stdout "start spill list\n";
	(match l with
	|t::q -> Printf.fprintf stdout "%s  %i\n" (Id.to_string (fst t)) (snd t); print_spill q
	| [] -> ());
	Printf.fprintf stdout "end spill list\n"



(** This function is to add active variable into active list and to sort active list in order of decreasing the endpoint of variables. 
	@param tpl the tuple element needed to be added into active list
	@param l the active list
	@return updated active list
*)
let rec add_to_active tpl l = 
	match l with
	|t::q -> if (trd t) > (trd tpl) then 
				t :: (add_to_active tpl q) 
			 else 
			 	tpl::t::q
			 	
	|[] -> [tpl;]
	
	
	
(** spill_active_var we will spill the first elememt in active list in to memory
	@param l spill list
	@param id the var need to be alloc
	@return "f_R%i__addr"
*)
let rec spill_active_var id l=
	let fst_id = (fst_ning (List.hd !active)) in
	match l with
	|t::q -> if (fst t) = fst_id then 
				(let id_pre = (if (String.sub (Id.to_string (snd_ning (List.hd !active))) 0 1) = "f" then
								  (String.sub (Id.to_string (snd_ning (List.hd !active))) 2 2)
							   else
								   (Id.to_string (snd_ning (List.hd !active)))) in
								   
				let reg_id:Id.t = sprintf "f_%s__%i" (id_pre) (snd t) in
				active := List.tl !active;
				reg_id)
				
			else 
				spill_active_var id q
			
	|[] ->  spill_counter := !spill_counter - 4;
			let id_pre = (if (String.sub (Id.to_string (snd_ning (List.hd !active))) 0 1) = "f" then
							 (String.sub (Id.to_string (snd_ning (List.hd !active))) 2 2)
						  else
							  (Id.to_string (snd_ning (List.hd !active)))) in
				
			let reg_id:Id.t = sprintf "f_%s__%i" (id_pre) (!spill_counter) in
			spill := (fst_id, !spill_counter) :: !spill;
			active := List.tl !active;
			reg_id
	
	

(** expire_active_list is to remove the first dead variable in the active list upto the startpoint if var id
	@param id a variable, in type Id.t
	@param l active list
	@return active list 
*)
let rec expire_active_list id l live_interval_s_ht =
	match l with
	|t::q -> if (trd t) < (Hashtbl.find live_interval_s_ht id) then 
				(free_reg := (snd_ning t) :: !free_reg;
				q)
			else t:: (expire_active_list id q live_interval_s_ht)
			
	|[] -> []



(** register_alloc is to alloc a register to a new defined variable
	@param id the variable newly defined which needs ti be assigned to a register
	@return "R%i" or "f_R%i__addr"(return value of spill_active_var)
*)
let register_alloc id live_interval_s_ht=
	active := expire_active_list id !active live_interval_s_ht;
	if (List.length !free_reg) = 0 then
		spill_active_var id !spill
	else 
		(let reg_id:Id.t = List.hd !free_reg in
		free_reg := List.tl !free_reg;
		reg_id)
		
		
		
(** This function is to do register allocation on a variable which is already definded and is in spill list when there's no free register left. 
	First we need to spill one variable in active list ,then give the register to the variable we need
	@param l spill list
	@param id the variable needed to be allocated 
	@return "f_R%i_load_store"
*)
let rec load_spill_active_var id l addr live_interval_e_ht =
	let fst_ning_id = (fst_ning (List.hd !active)) in
	match l with
	|t::q -> if (fst t) = fst_ning_id then 
				(let id_pre = (if (String.sub (Id.to_string (snd_ning (List.hd !active))) 0 1) = "f" then
								  (String.sub (Id.to_string (snd_ning (List.hd !active))) 2 2)
							   else
								  (Id.to_string (snd_ning (List.hd !active)))) in
				let reg_id:Id.t = sprintf "f_%s_%i_%i" (id_pre) (addr) (snd t) in
				active := List.tl !active;
				active := add_to_active (id, id_pre, (Hashtbl.find live_interval_e_ht id)) !active;
				reg_id)
			else 
				load_spill_active_var id q addr live_interval_e_ht
				
	|[] ->  spill_counter := !spill_counter - 4;
			active := List.tl !active;
			let id_pre = (if (String.sub (Id.to_string (snd_ning (List.hd !active))) 0 1) = "f" then
							(String.sub (Id.to_string (snd_ning (List.hd !active))) 2 2)
						  else
							(Id.to_string (snd_ning (List.hd !active)))) in
			let reg_id:Id.t = sprintf "f_%s_%i_%i" (id_pre) (addr) (!spill_counter) in
			active := add_to_active (id, (id_pre), (Hashtbl.find live_interval_e_ht id)) !active;
			spill := (fst_ning_id, !spill_counter) :: !spill;
			reg_id
	


(** load_alloc_reg is a to load a variable which is in memory into a new register and add it into active list. we will first alloc a new register, load it into the new register and add it into active variable list;
	@param id the variable need to be load to a register, in type Id.t
	@param l_spill the spill list
	@return a register and the load address in model "f_R%i_addr_addr", in type Id.t
*)
let load_alloc_reg id addr live_interval_s_ht live_interval_e_ht =
	active := expire_active_list id !active live_interval_s_ht;
	if (List.length !free_reg) = 0 then
		load_spill_active_var id !spill addr live_interval_e_ht
	else
		(active := add_to_active (id, ((List.hd !free_reg):Id.t), (Hashtbl.find live_interval_e_ht id) ) !active;
		let reg_id:Id.t = sprintf "f_%s_%i_" (List.hd !free_reg) (addr) in
		reg_id)


	
(** alloc_id_spill is a to assign a register to a variable which is in memory. we will find it in spill list, alloc a new register, load it into the new register and add it into active variable list;
	@param id the variable need to be foud in spill list and be assigned to a register, in type Id.t
	@param l_spill the spill list
	@return a register and the load address in model "f_R%i_addr_addr", in type Id.t
*)
let rec alloc_id_spill id l_spill live_interval_s_ht live_interval_e_ht =
	match l_spill with
	|t::q -> if (fst t) = id then load_alloc_reg id (snd t) live_interval_s_ht live_interval_e_ht else alloc_id_spill id q live_interval_s_ht live_interval_e_ht
	|[] -> failwith ("failure with find variable in spill list")



(** alloc_id is a to assign a register to a variable which is already defined before. if this variable is already in the active  variable list , we will return the register which is already assigned to it; else it's in memory, we will alloc a new register, find it in spill list, load it into the new register;
	@param id the variable need to be assigned, in type Id.t
	@param l the active variable list 
	@return a register, in type Id.t
*)
let rec alloc_id id l  live_interval_s_ht live_interval_e_ht =
	if (not (Hashtbl.mem live_interval_e_ht id)) then failwith ("failure with finding a used local variable in live_interval_e");
	match l with
	|t::q -> if (fst_ning t) = id then (snd_ning t) else alloc_id id q live_interval_s_ht live_interval_e_ht
	|[] -> alloc_id_spill id !spill	live_interval_s_ht live_interval_e_ht



(** alloc_id_def is a to alloc a register to a new defined variable and add the new variable into active variable list;
	@param id a new defined variable, in type Id.t
	@param a register, in type Id.t
*)
let alloc_id_def id live_interval_s_ht live_interval_e_ht = 
	let reg_id = register_alloc id live_interval_s_ht in
	if (not (Hashtbl.mem live_interval_e_ht id)) then failwith ("failure with finding a defined local variable in live_interval_e");
	let id_pre = (if (String.sub reg_id 0 1) = "f" then
				(String.sub reg_id 2 2)
			else
				reg_id) in
				
	active := add_to_active (id, id_pre, (Hashtbl.find live_interval_e_ht id)) !active;
	(*print_active !active;*)
	reg_id



let rec remove_from_free_reg l_free=
	match l_free with
	|t::q -> if t = "R0" then q else t::remove_from_free_reg q
	|[] -> failwith ("failure with linearscan funtion return value ")
	
	
	
let rec alloc_return_val id l_active = 
	let reg_id = 
	(match l_active with
	|t::q -> if (snd_ning t) = "R0" then 
				(spill_counter := !spill_counter - 4; spill := ((fst_ning t), !spill_counter) :: !spill; sprintf "f_R0__%i" (!spill_counter))
			else
				alloc_return_val id q
	|[] -> free_reg := remove_from_free_reg !free_reg; sprintf "R0" )in
	
	reg_id
	
	
	
let rec delete_from_active id_pre l_active =
	
	match l_active with
	|t::q -> if (snd_ning t) = id_pre then 
				q
			else 
				t :: (delete_from_active id_pre q)
				
	|[] -> failwith ("failure with linearscan funtion return value delete_from_active ")
	
	
	
(** This function is to allocate reister R0 to function return value
	@param id the variable for return value
	@return return variable with register allocation
*)
let alloc_id_return_val id l_active live_interval_s_ht live_interval_e_ht =
	let reg_id = alloc_return_val id l_active in
	let id_pre = (if (String.sub reg_id 0 1) = "f" then
					 (String.sub reg_id 2 2)
				  else
					  reg_id) in
	if (String.sub reg_id 0 1) = "f" then active := delete_from_active id_pre l_active;
	active := add_to_active (id, id_pre, (Hashtbl.find live_interval_e_ht id)) !active;
	reg_id
	 
	 
	 
(** This function is to do register alloction on function call arguments
	@param b arguments list of function calls
	@param l the active list
	@return allocsted arguments list of function calls
*)
let rec alloc_formalargs b l live_interval_s_ht live_interval_e_ht = 
	match b with
	|t::q -> (alloc_id t l live_interval_s_ht live_interval_e_ht) :: (alloc_formalargs q l live_interval_s_ht live_interval_e_ht)
	|[] -> []



(** This function is to do register alloction on function body
	@return function body with register instead of variables
*)
let rec alloc_exp e live_interval_s_ht live_interval_e_ht = 
	match e with
	|Int i -> Int i
	
	|Float i -> Float i
	
	|Neg id -> let reg_id = alloc_id id !active live_interval_s_ht live_interval_e_ht in 
			   Neg reg_id
	
	|Var id -> let reg_id = alloc_id id !active live_interval_s_ht live_interval_e_ht in 
			   Var reg_id
	
	|Add (a, b) -> let reg_a =alloc_id a !active live_interval_s_ht live_interval_e_ht in 
				   let reg_b = alloc_exp b live_interval_s_ht live_interval_e_ht in 
				   Add (reg_a, reg_b) 
	
	|Sub (a, b) -> let reg_a =alloc_id a !active live_interval_s_ht live_interval_e_ht in 
				   let reg_b = alloc_exp b live_interval_s_ht live_interval_e_ht in 
				   Sub (reg_a, reg_b) 
				   
	|Land (a, b) -> let reg_a =alloc_id a !active live_interval_s_ht live_interval_e_ht in 
					let reg_b = alloc_exp b live_interval_s_ht live_interval_e_ht in 
					Land (reg_a, reg_b)
					 
	|Call (a, b) -> let reg_b = alloc_formalargs b !active live_interval_s_ht live_interval_e_ht in 
					Call (a, reg_b)
	|If (a,b,c,d,e) -> let reg_a =alloc_id a !active live_interval_s_ht live_interval_e_ht in 
					   let reg_b = alloc_exp b live_interval_s_ht live_interval_e_ht in 
					   let reg_c =  alloc_asm c live_interval_s_ht live_interval_e_ht in 
					   let reg_d =  alloc_asm d live_interval_s_ht live_interval_e_ht in 
					   If (reg_a, reg_b, reg_c, reg_d, e)
					   
	|Eq (a, exp) -> let reg_a =alloc_id a !active live_interval_s_ht live_interval_e_ht in 
					let reg_exp = alloc_exp exp live_interval_s_ht live_interval_e_ht in 
					Eq (reg_a, reg_exp)
					
	|Nop -> Nop
	
	| _ -> failwith ("match failure with blinearscan expression: TODO")
	
	
	
	
and alloc_asm asm live_interval_s_ht live_interval_e_ht = 
	match asm with
	|Let (id, e, a) -> let reg_id = (match e with
					   					|Call (a,b) -> alloc_id_return_val id !active live_interval_s_ht live_interval_e_ht 
					   					| _ -> alloc_id_def id live_interval_s_ht live_interval_e_ht )in
					   					 
					   let reg_e = alloc_exp e live_interval_s_ht live_interval_e_ht in 
					   let reg_asm = alloc_asm a live_interval_s_ht live_interval_e_ht in
					   Let (reg_id, reg_e, reg_asm)
					   
	|Expression e -> let reg_e = alloc_exp e live_interval_s_ht live_interval_e_ht in Expression reg_e 

	
	
	
(** This function is to do register alloction on less or equal than 4 function arguments 
	@param args function arguments list from the first one to the fourth one if there are more than four arguments, if not ,it's the full function arguments list 
	@return registers list for arguments
*)
let rec active_args args live_interval_e_ht =
	match args with
	|t::q -> if (not (Hashtbl.mem live_interval_e_ht t)) then failwith ("failure with finding arg in live_interval_e");
			let x:Id.t = sprintf "%s" (List.hd !free_reg) in 
			free_reg := List.tl !free_reg;
			active := add_to_active (t, x, (Hashtbl.find live_interval_e_ht t)) !active;
			x :: (active_args q live_interval_e_ht)
			
	|[] -> []
	
	
	
(** This function is to do  register allocation on more than 4 function arguments
	@param args function arguments starting from the fifth one
	@param a frame position counter, start from 4
	@return registers list for arguments
*)
let rec spill_args args live_interval_e_ht a =
	match args with
	|t::q -> let reg_id = List.hd !free_reg in 
			 free_reg := List.tl !free_reg ;
			 active := add_to_active (t, reg_id, (Hashtbl.find live_interval_e_ht t)) !active;
			 (sprintf "f_%s_%i_" (reg_id) (a)) :: (spill_args q live_interval_e_ht (a+4))
			 
	|[] -> []
	
	
	
(** This function is to do register allocation on function arguments
	@return allocated arguments list
*)
let rec alloc_args args live_interval_e_ht =
	let reg_args = ref [] in
	
	if (List.length args) < 5 then
		reg_args := active_args args live_interval_e_ht
	else
		(match args with
		|a::b::c::d::e -> reg_args := active_args (a::b::c::d::[]:Id.t list) live_interval_e_ht; 
						  reg_args := !reg_args @ (spill_args e live_interval_e_ht 4)
						  
		|_ -> failwith ("failwith alloc_args"));
		
	!reg_args
		
		
			
(** This function does register allocation in a function
	@param fund the function need to be allocated
	@return function with registers
*)
let alloc_fund fund live_interval_s_ht live_interval_e_ht =
	spill_counter := 0;	
	free_reg := free_reg_pool;
	active := [];
	spill := [];
	let reg_args = (alloc_args fund.args live_interval_e_ht) in
	let reg_body = (alloc_asm fund.body live_interval_s_ht live_interval_e_ht) in
	{name = fund.name; args = reg_args; body = reg_body}



(** This function does register allocation in a list of functions
	@param funds function list
	@return function list with registers
*)
let rec alloc_funds funds live_interval_s_ht live_interval_e_ht= 
	match funds with
	|t::q -> let reg_fund = alloc_fund t live_interval_s_ht live_interval_e_ht in
			 reg_fund :: (alloc_funds q live_interval_s_ht live_interval_e_ht)
			 
	|[] -> []



(** This function is to do register allocation in type toplevel
	@param topl program in type toplevel
	@return program in toplevel with registers
*)	
let registeralloc topl live_interval_s_ht live_interval_e_ht=
	match topl with
	|Fundefs funds -> Fundefs (alloc_funds funds live_interval_s_ht live_interval_e_ht)
			
			
					  
