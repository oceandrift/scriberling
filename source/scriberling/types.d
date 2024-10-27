module scriberling.types;

alias hstring = const(char)[];

struct Location {
	hstring file;
	ptrdiff_t line;
	ptrdiff_t column;
}
