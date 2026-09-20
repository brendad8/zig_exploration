

const std = @import("std");

const Lexer = @This();

read_position: usize = 0,
position: usize = 0,
ch: u8 = 0,
line: usize = 1,
column: usize = 0,
input: []const u8,

const Token = struct 
{
    kind: TokenKind,
    line: usize,
    column: usize
};

const TokenKind = union(enum) 
{
    ident: []const u8,
    int: []const u8,

    illegal,
    eof,
    assign,
    plus,
    comma,
    semicolon,
    period,
    lparen,
    rparen,
    lsquirly,
    rsquirly,

    bitwise_and,
    bitwise_or,

    bang,
    dash,
    forward_slash,
    asterisk,
    less_than,
    greater_than,

    equal,
    not_equal,

    if_token,
    else_token,
    return_token,
    false_token,
    true_token,

    pound,
    typedef_token,
    struct_token,

    fn keyword(ident: []const u8) ?TokenKind {
        const map: std.StaticStringMap(TokenKind) = .initComptime(.{
            .{ "if", .if_token },
            .{ "true", .true_token },
            .{ "false", .false_token },
            .{ "return", .return_token },
            .{ "else", .else_token },
            .{ "typedef", .typedef_token },
            .{ "struct", .struct_token },
        });
        return map.get(ident);
    }
};


pub fn init(input: []const u8) Lexer 
{
    var lex: Lexer = .{
        .input = input
    };

    lex.readChar();

    return lex;
}

pub fn hasTokens(self: *Lexer) bool 
{
    return self.ch != 0;
}

pub fn nextToken(self: *Lexer) Token 
{
    self.skipWhitespace();

    var tok: Token = undefined;
    tok.line = self.line;
    tok.column = self.column;
    tok.kind = switch (self.ch) 
    {
        '{' => .lsquirly,
        '}' => .rsquirly,
        '(' => .lparen,
        ')' => .rparen,
        ',' => .comma,
        ';' => .semicolon,
        '.' => .period,
        '#' => .pound,
        '&' => .bitwise_and,
        '|' => .bitwise_or,
        '+' => .plus,
        '-' => .dash,
        '/' => .forward_slash,
        '*' => .asterisk,
        '<' => .less_than,
        '>' => .greater_than,
        '!' => blk: 
        {
            if (self.peekChar() == '=') 
            {
                self.readChar();
                break :blk .not_equal;
            } 
            else 
            {
                break :blk .bang;
            }
        },
        '=' => blk: 
        {
            if (self.peekChar() == '=') 
            {
                self.readChar();
                break :blk .equal;
            } 
            else 
            {
                break :blk .assign;
            }
        },
        'a'...'z', 'A'...'Z', '_' => blk:
        {
            const ident = self.readIdentifier();
            if (TokenKind.keyword(ident)) |kw| 
            {
                break :blk kw;
            }
            else
            {
                break :blk .{ .ident = ident };
            }
        },
        '0'...'9' => blk:
        {
            const int = self.readInt();
            break :blk .{ .int = int };
        },
        0 => .eof,
        else => .illegal,
    };

    self.readChar();
    return tok;
}

fn peekChar(self: *Lexer) u8 
{
    if (self.read_position >= self.input.len) 
    {
        return 0;
    } 
    else 
    {
        return self.input[self.read_position];
    }
}

fn readChar(self: *Lexer) void 
{
    if (self.read_position >= self.input.len) 
    {
        self.ch = 0;
    } 
    else 
    {
        self.ch = self.input[self.read_position];
    }

    if (self.ch == '\n')
    {
        self.line += 1;
        self.column = 0;
    }
    else
    {
        self.column += 1;
    }

    self.position = self.read_position;
    self.read_position += 1;
}

fn readIdentifier(self: *Lexer) []const u8 {
    const position = self.position;

    while (isLetter(self.ch)) 
    {
        self.readChar();
    }

    return self.input[position..self.position];
}

fn readInt(self: *Lexer) []const u8 
{
    const position = self.position;

    while (isInt(self.ch)) 
    {
        self.readChar();
    }

    return self.input[position..self.position];
}

fn skipWhitespace(self: *Lexer) void 
{
    while (std.ascii.isWhitespace(self.ch)) 
    {
        self.readChar();
    }
}

fn isLetter(ch: u8) bool 
{
    return std.ascii.isAlphabetic(ch) or ch == '_';
}

fn isInt(ch: u8) bool 
{
    return std.ascii.isDigit(ch);
}


