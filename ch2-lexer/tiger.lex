type pos = int
type lexresult = Tokens.token

val lineNum = ErrorMsg.lineNum
val linePos = ErrorMsg.linePos
val commentDepth = ref 0
val string = ref ""
fun err(p1,p2) = ErrorMsg.error p1

fun eof() = let val pos = hd(!linePos) in Tokens.EOF(pos,pos) end

%% 
%s STRING COMMENT;
ws = [\t\ ]+;
alpha = [A-Za-z];
digit = [0-9];
%%
<INITIAL>array    => (Tokens.ARRAY(yypos, yypos+5));
<INITIAL>break    => (Tokens.BREAK(yypos, yypos+5));
<INITIAL>do       => (Tokens.DO(yypos, yypos+2));
<INITIAL>else     => (Tokens.ELSE(yypos, yypos+4));
<INITIAL>end      => (Tokens.END(yypos, yypos+3));
<INITIAL>for      => (Tokens.FOR(yypos, yypos+3));
<INITIAL>function => (Tokens.FUNCTION(yypos, yypos+8));
<INITIAL>if       => (Tokens.IF(yypos, yypos+2));
<INITIAL>in       => (Tokens.IN(yypos, yypos+2));
<INITIAL>let      => (Tokens.LET(yypos, yypos+3));
<INITIAL>nil      => (Tokens.NIL(yypos, yypos+3));
<INITIAL>of       => (Tokens.OF(yypos, yypos+2));
<INITIAL>then     => (Tokens.THEN(yypos, yypos+4));
<INITIAL>to       => (Tokens.TO(yypos, yypos+2));
<INITIAL>type     => (Tokens.TYPE(yypos, yypos+4));
<INITIAL>var      => (Tokens.VAR(yypos, yypos+3));
<INITIAL>while    => (Tokens.WHILE(yypos, yypos+5));

<INITIAL>"{"      => (Tokens.LBRACE(yypos, yypos+1));
<INITIAL>"}"      => (Tokens.RBRACE(yypos, yypos+1));
<INITIAL>","      => (Tokens.COMMA(yypos, yypos+1));
<INITIAL>":"      => (Tokens.COLON(yypos, yypos+1));
<INITIAL>";"      => (Tokens.SEMICOLON(yypos, yypos+1));
<INITIAL>"("      => (Tokens.LPAREN(yypos, yypos+1));
<INITIAL>")"      => (Tokens.RPAREN(yypos, yypos+1));
<INITIAL>"["      => (Tokens.LBRACK(yypos, yypos+1));
<INITIAL>"]"      => (Tokens.RBRACK(yypos, yypos+1));
<INITIAL>"."      => (Tokens.DOT(yypos, yypos+1));
<INITIAL>"+"      => (Tokens.PLUS(yypos, yypos+1));
<INITIAL>"-"      => (Tokens.MINUS(yypos, yypos+1));
<INITIAL>"*"      => (Tokens.TIMES(yypos, yypos+1));
<INITIAL>"/"      => (Tokens.DIVIDE(yypos, yypos+1));
<INITIAL>"="      => (Tokens.EQ(yypos, yypos+1));
<INITIAL>"<>"     => (Tokens.NEQ(yypos, yypos+2));
<INITIAL>"<"      => (Tokens.LT(yypos, yypos+1));
<INITIAL>"<="     => (Tokens.LE(yypos, yypos+2));
<INITIAL>">"      => (Tokens.GT(yypos, yypos+1));
<INITIAL>">="     => (Tokens.GE(yypos, yypos+2));
<INITIAL>"&"      => (Tokens.AND(yypos, yypos+1));
<INITIAL>"|"      => (Tokens.OR(yypos, yypos+1));
<INITIAL>":="     => (Tokens.ASSIGN(yypos, yypos+2));
<INITIAL>"/*"     => (YYBEGIN COMMENT; continue());
<INITIAL>\"\"     => (Tokens.STRING("", yypos, yypos+2));
<INITIAL>\"       => (YYBEGIN STRING; continue());

<INITIAL>{ws}     => (continue());
<INITIAL>{alpha}({alpha}|{digit}|_)* => (Tokens.ID(yytext, yypos, yypos + (size yytext)));
<INITIAL>{digit}+ => (let
                         val SOME x = Int.fromString yytext;
                      in
                         Tokens.INT(x, yypos, yypos + (size yytext))
                      end);

<COMMENT>"/*"     => (commentDepth := !commentDepth+1; continue());
<COMMENT>"*/"     => (if !commentDepth=0 then (YYBEGIN INITIAL; continue()) else (commentDepth := !commentDepth-1; continue()));
<COMMENT>.        => (continue());

<STRING>[^\\]\"   => (YYBEGIN INITIAL; 
                      let 
                          val tmp = !string;
                          val prematch = substring (yytext, 0, 1);
                          val tmp = tmp ^ prematch
                      in 
                          string := "";
                          Tokens.STRING(tmp, yypos, yypos + (size (tmp) + 2))
                      end
                     );
<STRING>.         => (string := !string ^ yytext; continue());


\n	=> (lineNum := !lineNum+1; linePos := yypos :: !linePos; continue());
.       => (ErrorMsg.error yypos ("illegal character " ^ yytext); continue());

