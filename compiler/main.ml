let display_version = ref false
let type_check_only = ref false
let parse_only = ref false
let asml_only = ref false
let version = ref "Version: Fancy Camembert"
let output_file = ref "a.out"

let print_asml l =
    let s = (Fparser.exp Flexer.token l) in
    if !asml_only then
        Fasmlgen.closure_to_asmlstring_main (Fclosure.clos (Freduction.reduc (Fknormal.knormal s)))
    else
        let prog = Fasmlgen.asml_head (Fclosure.clos_exp (Freduction.reduc (Fknormal.knormal s))) in
        (*Barmgenerator.toplevel_to_arm prog*)
        Barmspillgenerator.toplevel_to_arm prog

let file fin fout =
    let inchan = open_in fin in
    let outchan = open_out fout in
    try
       if !type_check_only then
       begin
         let s = (Fparser.exp Flexer.token (Lexing.from_channel inchan)) in
           Typechecking.genEquations s Unit; print_string "well typed\n"
       end
     else
         begin
            Printf.fprintf outchan "%s" (print_asml (Lexing.from_channel inchan));
            print_endline (Printf.sprintf "Successfully created file %s" !output_file);
        end;
    close_in inchan;
    close_out outchan
    with e -> (close_in inchan; close_out outchan; raise e)

let () =
    let input_file = ref "" in
    let optionlist = [
        ("-o", Arg.Set_string output_file, "Specify output file (default a.out)");
        ("-v", Arg.Set display_version, "Display the version");
        ("-t", Arg.Set type_check_only, "Type check only");
        ("-p", Arg.Set parse_only, "Parse only");
        ("-asml", Arg.Set asml_only, "Output ASML only");
        ("-h", Arg.Unit (fun _ -> ()), "Dislay this list of options (TODO)")
    ] in

    Arg.parse
        optionlist
        (fun s -> input_file := s)
        "Mincaml compiler for ARMv7 architecture";


    if !display_version then
        print_endline !version;

    if !input_file = "" then
        failwith (Printf.sprintf "usage: %s filename" Sys.argv.(0))
    else
        file !input_file !output_file
