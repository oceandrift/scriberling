/++
	HTML escaping
 +/
module scriberling.data.html;

import std.conv;
import std.range : ElementType, isInputRange;
import std.typecons;
import scriberling.data.unicode;
import scriberling.types;

@safe pure:

///
enum EscapeCharacterSelection : ubyte {
	///
	none = 0b_0000_0000,

	// dfmt off
	///
	amp  = 0b_0000_0001,
	///
	lt   = 0b_0000_0010,
	///
	gt   = 0b_0000_0100,
	///
	quot = 0b_0000_1000,
	///
	d39  = 0b_0001_0000,
	// dfmt on

	///
	content = (amp | lt | gt),
	///
	attributeDoubleQuotesOnly = (amp | lt | gt | quot),
	///
	attribute = (amp | lt | gt | quot | d39),

	///
	all = 0b_1111_1111,
}

private {
	struct Escape {
		char specialChar;
		string escapeSequence;
	}

	Escape[] getEscapeMap(EscapeCharacterSelection escapeChars) nothrow {
		auto m = new Escape[](0);

		if (escapeChars & EscapeCharacterSelection.amp) {
			m ~= Escape('&', "&amp;");
		}
		if (escapeChars & EscapeCharacterSelection.lt) {
			m ~= Escape('<', "&lt;");
		}
		if (escapeChars & EscapeCharacterSelection.gt) {
			m ~= Escape('>', "&gt;");
		}
		if (escapeChars & EscapeCharacterSelection.quot) {
			m ~= Escape('"', "&quot;");
		}
		if (escapeChars & EscapeCharacterSelection.d39) {
			m ~= Escape('\'', "&#39;");
		}

		return m;
	}
}

/++
	HTML escaping implementation
 +/
struct HTMLEscaper(EscapeCharacterSelection escapeChars = EscapeCharacterSelection.all) {
@safe pure nothrow:

	private {
		static immutable _escapeMap = getEscapeMap(escapeChars);

		hstring _input;

		bool _empty = true;
		char _front;

		hstring _buffer = null;
	}

	/++
		See_Also:
			[htmlEscape]
	 +/
	this(hstring input) @nogc {
		_empty = false;
		_input = input;
		loadFront();
	}

	///
	bool empty() @nogc {
		return _empty;
	}

	///
	char front() @nogc {
		return _front;
	}

	///
	void popFront() @nogc {
		if (_buffer.length > 0) // data in buffer?
		{
			_front = _buffer[0];
			_buffer = _buffer[1 .. $];
			return;
		}

		_input.popFront();
		this.loadFront();
	}

	private void loadFront() @nogc {
		if (_input.empty) // input empty?
		{
			_empty = true;
			return;
		}

		// dfmt off

		// needs escaping?
		switch (_input.front) {
			default:
				break;

			static foreach (esc; _escapeMap) {
				case esc.specialChar:
					_front = esc.escapeSequence[0]; // store first char of escape sequence in front
					_buffer = esc.escapeSequence[1 .. $]; // load rest into buffer
					return;
			}
		}
		// dfmt on

		// no escaping
		_front = _input.front;
	}

	///
	hstring toHString() {
		import std.range : array;

		return array(this);
	}
}

/++
	Escape input for use in HTML

	Escaping of quotes (double quotes (`"`) and single quotes (`'`))
	can be configured by using the first template parameter.
	Use `htmlEscape!false()` to disable escaping of quotes.

	Returns:
		Input Range; call `.toHString` to convert it into an hstring
 +/
HTMLEscaper!(escapeChars) htmlEscape(
	EscapeCharacterSelection escapeChars = EscapeCharacterSelection.all,
)(
	hstring input,
) nothrow @nogc {
	return HTMLEscaper!escapeChars(input);
}

unittest {
	auto escaped = htmlEscape("<html>");
	assert(!escaped.empty);
	assert(escaped.front == '&');

	escaped.popFront();
	assert(escaped.front == 'l');
	escaped.popFront();
	assert(escaped.front == 't');
	escaped.popFront();
	assert(escaped.front == ';');
	escaped.popFront();
	assert(escaped.front == 'h');
	escaped.popFront();
	assert(escaped.front == 't');
	escaped.popFront();
	assert(escaped.front == 'm');
	escaped.popFront();
	assert(escaped.front == 'l');
	escaped.popFront();
	assert(escaped.front == '&');
	escaped.popFront();
	assert(escaped.front == 'g');
	escaped.popFront();
	assert(escaped.front == 't');
	escaped.popFront();
	assert(escaped.front == ';');

	escaped.popFront();
	assert(escaped.empty);
}

///
unittest {
	assert(htmlEscape("foo bar").toHString == "foo bar");

	assert(htmlEscape("<html>").toHString == "&lt;html&gt;");
	assert(htmlEscape("<<html>>").toHString == "&lt;&lt;html&gt;&gt;");

	assert(htmlEscape("Dlang & co.").toHString == "Dlang &amp; co.");

	assert(htmlEscape(`<p style="background: #FFF">`)
			.toHString == "&lt;p style=&quot;background: #FFF&quot;&gt;");

	assert(htmlEscape!(EscapeCharacterSelection.content)(`<p style="background: #FFF">`)
			.toHString == `&lt;p style="background: #FFF"&gt;`);

	assert(htmlEscape(`<p style='background: #FFF'>`)
			.toHString == `&lt;p style=&#39;background: #FFF&#39;&gt;`);

	hstring txt = `<better escape="me" />`;
	assert(htmlEscape(txt).toHString == "&lt;better escape=&quot;me&quot; /&gt;");
}

///
unittest {
	// Chain url-decoding with html-escaping:
	import scriberling.data.uri;

	// <script>alert('xss');</script>
	const decodedAndEscaped = urlDecode("%3Cscript%3Ealert%28%27xss%27%29%3B%3C%2Fscript%3E")
		.toHString
		.htmlEscape()
		.toHString;

	assert(decodedAndEscaped == "&lt;script&gt;alert(&#39;xss&#39;);&lt;/script&gt;");
}

private {
	static immutable string[string] entitiesTable = mixin(import("scriberling/data/html-entities.txt"));
}

/++
	Decodes an HTML entity.

	E.g. turns either of `&copy;`, `&#169;` or `&#xA9;` into `©`.
 +/
string htmlDecodeEntity(hstring entity) nothrow {
	const resolved = htmlResolveEntity(entity);
	if (resolved !is null) {
		return resolved;
	}

	if ((entity.length < 3) || (entity[1] != '#')) {
		return replacementCharacterString;
	}

	if (entity[$ - 1] == ';') {
		entity = entity[0 .. ($ - 1)];
	}

	ulong codepoint;

	try {
		if (entity[2] == 'x') {
			codepoint = entity[3 .. $].to!uint(16);
		} else {
			codepoint = entity[2 .. $].to!uint();
		}
	} catch (Exception) {
		return replacementCharacterString;
	}

	return encodeCodepoint(cast(dchar) codepoint);
}

///
unittest {
	assert(htmlDecodeEntity("&copy;") == "©");
	assert(htmlDecodeEntity("&copy") == "©");
	assert(htmlDecodeEntity("&#169;") == "©");
	assert(htmlDecodeEntity("&#xA9;") == "©");

	assert(htmlDecodeEntity("&#x1F1E9;") == "\U0001F1E9");

	// replacement char
	assert(htmlDecodeEntity("&#nonsense;") == "\uFFFD");
}

/++
	Resolves an HTML entity name.

	E.g. turns `&copy;` into `©`.
 +/
string htmlResolveEntity(hstring entity) nothrow @nogc {
	const str = entity in entitiesTable;

	if (str is null) {
		return null;
	}

	return *str;
}

///
unittest {
	assert(htmlResolveEntity("&copy;") == "©");
	assert(htmlResolveEntity("&copy") == "©");
	assert(htmlResolveEntity("&auml;") == "ä");
	assert(htmlResolveEntity("&Auml;") == "Ä");
	assert(htmlResolveEntity("&nbsp;") == "\u00A0");
}
