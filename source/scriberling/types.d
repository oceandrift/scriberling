/++
	Library base types
 +/
module scriberling.types;

///
alias hstring = const(char)[];

public @safe pure nothrow @nogc {

	/++
		Emulates an input range for [hstring].

		No auto-decoding.
	 +/
	char front(const hstring s) {
		return s[0];
	}

	/// ditto
	bool empty(const hstring s) {
		return (s.length == 0);
	}

	/// ditto
	void popFront(ref hstring s) {
		s = s[1 .. $];
	}
}

///
struct Location {
	///
	hstring file;
	///
	ptrdiff_t line;
	///
	ptrdiff_t column;
}
