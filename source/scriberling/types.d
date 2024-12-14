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

	/++
		Byte offset
	 +/
	long offset = 0;
}

/++
	Human-readable location
 +/
struct EditorLocation {
	///
	hstring file;

	///
	long line = 1;

	///
	long column = 1;

	///
	static typeof(this) fromLocation(Location location, hstring sourceCode, int tabWidth = 1) {
		import std.uni;

		const relevantCode = sourceCode[0 .. location.offset];
		auto result = EditorLocation(location.file, 1, 1);

		size_t idxLastLine = 0;

		// line number
		foreach (idx, c; relevantCode) {
			if (c == '\n') {
				bool isCRLF = ((idx >= 1) && relevantCode[idx - 1] == '\r');
				if (!isCRLF) {
					++result.line;
				}

				idxLastLine = (idx + 1);
			} else if (c == '\r') {
				++result.line;
				idxLastLine = (idx + 1);
			}
		}

		const lastLine = relevantCode[idxLastLine .. $];

		// column number
		foreach (g; lastLine.byGrapheme) {
			// tab?
			if (g[] == "\t") {
				result.column += tabWidth;
				continue;
			}

			++result.column;
		}

		return result;
	}
}
