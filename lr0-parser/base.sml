(* LR(0) Parser for Grammer 3.20 *)
(* TODO: add grammar *)
datatype terminal = LPAREN | RPAREN | ID | COMMA
datatype nonterminal = START | S | L | ACCEPT

datatype symbol = TSymbol of terminal | NSymbol of nonterminal
val symbols = [
  TSymbol LPAREN,
  TSymbol RPAREN,
  TSymbol ID,
  TSymbol COMMA,
  NSymbol START, 
  NSymbol S, 
  NSymbol L, 
  NSymbol ACCEPT
]

datatype action = GOTO of int | SHIFT of int | A_ACCEPT | REDUCE of int  
type rule = nonterminal * symbol list
type item = rule * int
type state = item list
type edge = state * symbol * state
type cell = int * symbol * action

val rule0 = (START, [NSymbol S, NSymbol ACCEPT])
val rule1 = (S, [TSymbol LPAREN, NSymbol L, TSymbol RPAREN])
val rule2 = (S, [TSymbol ID])
val rule3 = (L, [NSymbol S])
val rule4 = (L, [NSymbol L, TSymbol COMMA, NSymbol S]) 
val rules = [rule0, rule1, rule2, rule3, rule4];

(* Helper functions *)
fun rhs ((_, r):rule):symbol list = r
fun lhs ((l, _):rule):nonterminal = l

fun getRule ((r, _):item):rule = r
fun getPos  ((_, p):item):int = p
fun get_rule_id i_rule []      count = 99
  | get_rule_id i_rule (x::xs) count = 
    case (i_rule = x) of
       true  => count
     | false => get_rule_id i_rule xs (count + 1)

fun flat xs = List.foldr op@ [] xs

fun unique' x []      = []
  | unique' x (y::ys) = 
    case x = y of
       true  => unique' x ys
     | false => y::(unique' x ys)
fun unique []     = []
  | unique (x::y) =
      let
        val a = unique' x y
      in
        x::(unique a)
      end

fun idx_list_insert x ys 0        = x::ys
  | idx_list_insert x [] idx      = x::[]
  | idx_list_insert x (y::ys) idx = y::(idx_list_insert x ys (idx-1))

fun inc_item_pos (i_rule, idx):item = (i_rule, idx+1)

fun zip_make_eq empty []      []      = []
  | zip_make_eq empty []      (y::ys) = (empty, y)::(zip_make_eq empty [] ys)
  | zip_make_eq empty (x::xs) []      = (x, empty)::(zip_make_eq empty xs [])
  | zip_make_eq empty (x::xs) (y::ys) = (x, y)::(zip_make_eq empty xs ys)

fun join_string_list []      = ""
  | join_string_list (x::[]) = x
  | join_string_list (x::xs) = x ^ (join_string_list xs)

(* List equality ops *)
fun list_contains x xs = List.exists (fn y => y = x) xs

fun list_subset xs ys =
  let 
    val all_contain = map (fn x => list_contains x ys) xs
  in
    List.foldr (fn (x, y) => x andalso y) true all_contain
  end

fun lists_eq xs ys =
  let
    val same_size = (List.length xs) = (List.length ys)
  in
    case same_size of
       true => (list_subset xs ys) andalso (list_subset ys xs)
     | false => false
  end

(* Next symbol in item *)
fun nextUp item = 
  let 
    val r = rhs (getRule item)
    val pos = getPos item
  in
    case pos < List.length r of
       true  => SOME (List.nth(r, pos))
     | false => NONE
  end

(* Create starting item for the given rule if it starts with the given symbol *)
fun getItem i_symbol i_rule =
  case lhs(i_rule) = i_symbol of
     true  => SOME (i_rule, 0)
   | false => NONE

(* Create a list of all items for the given symbol *)
fun getItems (i_symbol:nonterminal):state =
  let
    val opt_items = map (getItem i_symbol) rules
    val some_items = List.filter (isSome) opt_items
  in
    map (valOf) some_items
  end
  
(* Create a one-iteration closure for the given item *)
fun closure' (i_item:item):state =
  let 
     val nxt = nextUp i_item
  in 
     case isSome nxt of
        true  => (case valOf nxt of
                    NSymbol n => i_item :: (getItems n)
                  | TSymbol t => [i_item])
      | false => [i_item]
  end

fun closure (i_state:state):state =
  let
    val new_state = unique (flat (map (closure') i_state))
  in
    case new_state = i_state of
       true  => new_state
     | false => closure new_state
  end

fun goto i_state i_symbol = 
  let 
    val opt_inc_items = 
       map (
             fn i_item => 
                case (nextUp i_item) = (SOME i_symbol) of
                   true  => SOME (inc_item_pos i_item)
                 | false => NONE
           ) i_state
    val some_inc_items = List.filter isSome opt_inc_items
    val j = map valOf some_inc_items
  in
     closure j
  end

fun reachable_state_and_its_edge i_state i_item =
  let 
    val x = nextUp i_item
  in
    case isSome x of
       true  => 
         let
           val j = goto i_state (valOf x)
         in
           SOME (j, (i_state, valOf x, j))
         end
     | false => NONE
  end

(* Returns a list of reachable states w/ their edge *)
fun reachable_states_and_their_edges i_state =
  let
   val vals = map (fn i_item => reachable_state_and_its_edge i_state i_item) i_state
   val state_edge_pairs = map valOf (List.filter isSome vals)
   val state_list = map #1 state_edge_pairs
   val edge_list = map #2 state_edge_pairs 
  in
   (state_list, edge_list)
  end

fun get_all_states_and_edges (state_list:state list) edge_list =
  let
    val states_and_edges = map reachable_states_and_their_edges state_list
    val state_list_list = map #1 states_and_edges
    val edge_list_list = map #2 states_and_edges
    val new_state_list = unique ((flat state_list_list) @ state_list)
    val new_edge_list  = unique ((flat edge_list_list) @ edge_list)
  in
    case (lists_eq new_state_list state_list) andalso (lists_eq new_edge_list  edge_list) of
       true  => (new_state_list, new_edge_list)
     | false => get_all_states_and_edges new_state_list new_edge_list
  end

fun map_states_to_ids []      id = []
  | map_states_to_ids (x::xs) id = (id, x)::(map_states_to_ids xs (id+1))

fun get_mapped_state []              id = NONE
  | get_mapped_state ((i_id, s)::xs) id = if i_id = id then SOME s else get_mapped_state xs id

fun get_state_id []              s = NONE
  | get_state_id ((id, i_s)::xs) s = if i_s = s then SOME id else get_state_id xs s

fun construct_parsing_table_shift_goto mapped_states edge_list =
  let
    val some_shifts_and_gotos = map (fn (i, s, j) =>
      let
        val opt_id_j = get_state_id mapped_states j
        val opt_id_i = get_state_id mapped_states i
      in
        case opt_id_j of
           SOME id =>
              (case opt_id_i of
                  SOME id_i =>
                     (case s of
                         NSymbol n => SOME (id_i, s, (GOTO id))
                       | TSymbol t => SOME (id_i, s, (SHIFT id)))
                | NONE => NONE)
         | NONE => NONE
      end  
    ) edge_list
  in
    map valOf (List.filter isSome some_shifts_and_gotos)
  end

fun construct_parsing_table_accept mapped_states =
  let
    val accepted_states = map (fn (id, i_state) =>
      map (fn i_item =>
        case nextUp i_item of
           SOME (NSymbol ACCEPT) => SOME (id, NSymbol ACCEPT, A_ACCEPT)
         | SOME (NSymbol _) => NONE
         | SOME (TSymbol _) => NONE
         | NONE => NONE
      ) i_state
    ) mapped_states
  in
    map valOf (List.filter (isSome) (flat accepted_states))
  end 

fun construct_parsing_table_reduce mapped_states =
  let
    val opt_reduce_states = map (fn (id, i_state) =>
      map (fn i_item =>
        map (fn i_symbol =>
          case nextUp i_item of
             NONE => SOME (id, i_symbol, REDUCE (get_rule_id (getRule i_item) rules 0))
           | SOME _ => NONE 
        ) symbols
      ) i_state
    ) mapped_states
    val some_reduce_states = List.filter isSome (flat (flat opt_reduce_states))
  in
    map valOf some_reduce_states
  end

fun get_table_action i_state_id i_symbol []    = NONE
  | get_table_action i_state_id i_symbol ((z_state_id, z_symbol, z_action)::cells) =
      case (i_state_id = z_state_id) andalso (i_symbol = z_symbol) of
         true  => SOME z_action
       | false => get_table_action i_state_id i_symbol cells

(* Print functions*)
fun nonterminal_to_string i_nonterminal =
  case i_nonterminal of
      START  => "S'"
    | S      => "S"
    | L      => "L"
    | ACCEPT => "$"

fun terminal_to_string i_terminal =
  case i_terminal of
      LPAREN => "("
    | RPAREN => ")"
    | ID     => "x"
    | COMMA  => ","

fun symbol_to_string i_symbol =
  case i_symbol of
      NSymbol n => nonterminal_to_string n
    | TSymbol t => terminal_to_string t

fun action_to_string i_action = 
  case i_action of
     GOTO x => "g" ^ Int.toString(x)
   | SHIFT x => "s" ^ Int.toString(x)
   | A_ACCEPT => "a" 
   | REDUCE x => "r" ^ Int.toString(x)

fun rhs_rule_to_string i_rule = 
  concat (map symbol_to_string (rhs i_rule))
 
fun lhs_rule_to_string i_rule = 
  nonterminal_to_string (lhs i_rule)
 
fun rule_to_string i_rule = 
   (lhs_rule_to_string i_rule) ^ " => " ^ (rhs_rule_to_string i_rule)

fun item_to_string i_item =
  let
    val i_rule = getRule i_item
    val char_list = explode (rhs_rule_to_string i_rule)
    val pos  = getPos i_item
    val rhs_pos = implode (idx_list_insert #"." char_list pos)
  in
    (lhs_rule_to_string i_rule) ^ " => " ^ rhs_pos
  end

fun state_to_string i_state =
  map item_to_string i_state

fun edge_to_string (i, x, j) =
  let
    val i_state_string = state_to_string i
    val j_state_string = state_to_string j
    val zipd = zip_make_eq "         " i_state_string j_state_string
    val middle = "              |                "
    val header = "======================" ^ (symbol_to_string x) ^ "=================>\n"
    val body = map (fn (x, y) => x ^ middle ^ y ^ "\n") zipd
  in
    header :: body
  end

fun state_list_to_string state_list = 
  let 
    val string_list_list = map state_to_string state_list
  in
    map (fn string_list => 
       let
        val state_strings = map (fn i_string => 
            i_string ^ "\n"
          ) string_list 
        val divider = "--------------------------\n"
       in
          print ((join_string_list state_strings) ^ divider)
       end
    ) string_list_list
  end

fun mapped_state_list_to_string mapped_state_list = 
  let 
    val id_string_list_list = map (fn (id, i_state) => 
      (id, state_to_string i_state)
    ) mapped_state_list
  in
    map (fn (id, string_list) => 
       let
        val state_strings = map (fn i_string => 
            i_string ^ "\n"
          ) string_list 
        val divider = "--------------STATE " ^ Int.toString id ^ "----------------------\n"
       in
          print ((join_string_list state_strings) ^ divider)
       end
    ) id_string_list_list
  end

fun edge_list_to_string edge_list =
  let 
    val string_list_list = map edge_to_string edge_list
  in
    map (fn string_list => 
       let
        val state_strings = map (fn i_string => 
            i_string ^ "\n"
          ) string_list 
        val divider = "--------------------------\n"
       in
          print ((join_string_list state_strings) ^ divider)
       end
    ) string_list_list
  end

fun table_cells_to_string (i_id, i_symbol, i_action) =
  (Int.toString (i_id)) ^ ", " ^ (symbol_to_string i_symbol) ^ ", " ^ (action_to_string i_action)

fun print_parsing_table cells symbols mapped_states = 
  let
   (* Build the table header *)
   val header = " " ^ 
       (join_string_list (map (fn i_symbol =>
                            "  " ^ (symbol_to_string i_symbol) ^ " " 
                         ) symbols))
   (* Build the table row by row *)
   val table_rows = map (fn (id, i_state) =>
     let
       val opt_cell_values = map (fn i_symbol => get_table_action id i_symbol cells) symbols
     in
       (Int.toString id) ^ 
       (join_string_list (map (fn opt_cell_value =>
                           case opt_cell_value of
                              SOME a => "  " ^ (action_to_string a)
                            | NONE   => "    "
                         ) opt_cell_values))
     end
   ) mapped_states
   val all_rows = header::table_rows
  in 
    (* Add a newline to the end of each line & print *)
    join_string_list (map (fn i_string => i_string ^ "\n") all_rows)
  end

(* Build default items. *)
val alpha_item = (rule0, 0);
val alpha_state = closure [alpha_item]
val all_states_and_edges = get_all_states_and_edges [alpha_state] []
val mapped_states = map_states_to_ids (#1 all_states_and_edges) 0
val edges = (#2 all_states_and_edges)
val shifts_gotos = construct_parsing_table_shift_goto mapped_states edges
val accepts = construct_parsing_table_accept mapped_states
val reduces = construct_parsing_table_reduce mapped_states
val table_cells = shifts_gotos @ accepts @ reduces
val parsing_table = print_parsing_table table_cells symbols mapped_states
