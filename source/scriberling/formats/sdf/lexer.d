module scriberling.formats.sdf.lexer;

import std.ascii;
import scriberling.types;

/++
	Type of a Scriberling Document Format source token
 +/
enum SDFTokenType {
	///
	error,
	///
	whitespace,
	///
	identifier,
	///
	braceBlockOpening,
	///
	braceBlockClosing,
	///
	braceBlockOpeningWsCtrl,
	///
	braceBlockClosingWsCtrl,
	///
	escapeSeq,
	///
	comment,
	///
	metaBlock,
	///
	embeddedAppBlock,
	///
	text,
}

/++
	Scriberling Document Format source token
 +/
struct SDFToken {
	TokenType type;
	hstring data;
	Location location;
}

private alias Token = SDFToken;
private alias TokenType = SDFTokenType;

private static {
	immutable string errorMsgBinaryFile = "Binary data in text file.";

	immutable string errorMsgInvalidEscapeSeq = "Invalid escape sequence.";

	immutable string errorMsgMissingClosingTagBlockComment = "Block comment has no closing tag `*/`.";
	immutable string errorMsgMissingClosingTagBlockCommentNested = "Block comment has no closing tag `+/`.";

	immutable string errorMsgMissingClosingTagEmbeddedAppBlock = "Embedded app block has no closing tag `}}}`.";

	immutable string errorMsgMissingClosingTagMetaBlock = "Meta block has no closing tag `---`.";

	immutable string errorMsgMissingLineBreakOpeningTagEmbeddedAppBlock =
		"Missing line break after opening tag of embedded app block.";
	immutable string errorMsgMissingLineBreakClosingTagEmbeddedAppBlock =
		"Missing line break before closing tag of embedded app block.";

	immutable string errorMsgUnterminatedMetaBlock = "Unterminated meta block.";
}

/++
	Lexer for Scriberling Document Format source files
 +/
struct SDFLexer {

	private {
		hstring _source;

		bool _eof = true;
		Token _front;
		Location _location;
	}

@safe pure nothrow @nogc:

	///
	public this(hstring sourceCode, Location initialLocation = Location(null, 1, 1)) {
		_source = sourceCode;
		_location = initialLocation;

		_eof = false;
		this.popFront();
	}

	///
	bool empty() const {
		return _eof;
	}

	///
	Token front() {
		return _front;
	}

	///
	void popFront() {
		if (_source.length == 0) {
			_eof = true;
			return;
		}

		_front = this.lexToken();
	}

	private bool isOnFinalChar() {
		return (_source.length == 1);
	}

	private void advanceLocationToNextLine() {
		++_location.line;
		_location.column = 1;
	}

	private void advanceLocationBy(size_t n) {
		_location.column += n;
	}

	private Token makeToken(TokenType type, size_t dataLength) {
		auto result = Token(type, _source[0 .. dataLength], _location);

		_source = _source[dataLength .. $];
		this.advanceLocationBy(dataLength);

		return result;
	}

	private Token makeError(hstring errorMessage, size_t dataLength) {
		auto result = Token(TokenType.error, errorMessage, _location);

		_source = _source[dataLength .. $];
		this.advanceLocationBy(dataLength);

		return result;
	}

	private Token makeTextToken(size_t skip = 0) {
		ptrdiff_t length = _source[skip .. $].scanEndOfText();
		assert((length > 0) || (skip > 0));

		length += skip;

		// is identifier?
		ptrdiff_t lengthWhitespace = _source[length .. $].scanEndOfWhitespace();
		const idxNextToken = length + lengthWhitespace;
		if (idxNextToken != _source.length) {
			if (_source[idxNextToken] == '{') {
				return this.makeToken(TokenType.identifier, length);
			}
		}

		return this.makeToken(TokenType.text, length);
	}

	private Token makeWhitespaceToken() {
		Location loc = _location;
		ptrdiff_t length = _source.scanEndOfWhitespace(_location.line, _location.column);

		auto token = Token(
			TokenType.whitespace,
			_source[0 .. length],
			loc,
		);

		_source = _source[length .. $];
		return token;
	}

	private Token lexToken() {
		switch (_source[0]) {

		case '\x00': .. case '\x08':
			return Token(TokenType.error, errorMsgBinaryFile);

		case '\x09': // tab
		case '\x0A': // '\n' = LF
		case '\x0B': // vertical tab
		case '\x0C': // form feed
		case '\x0D': // '\r' (CR)
			return this.makeWhitespaceToken();

		case '\x0E': .. case '\x1F':
			return Token(TokenType.error, errorMsgBinaryFile);

		case '\x20': // space
			return this.makeWhitespaceToken();

		case '\x21': .. case '\x2C': // !"#$%&'()*+,
			return this.makeTextToken();

		case '\x2D': // '-'
			return this.lexDash();

		case '\x2E': // '.'
			return this.makeTextToken();

		case '\x2F': // '/'
			return this.lexSlash();

		case '\x30': .. case '\x39': // '0' .. '9'
		case '\x3A': .. case '\x40': // :;<=>?@
		case '\x41': .. case '\x5A': // 'A' .. 'Z'
		case '\x5B': // '['
			return this.makeTextToken();

		case '\x5C': /* '\\' */ {
				if (this.isOnFinalChar) {
					return this.makeError(errorMsgInvalidEscapeSeq, 1);
				}
				auto token = Token(
					TokenType.escapeSeq,
					_source[1 .. 2],
					_location,
				);

				_source = _source[2 .. $];
				_location.advance(_source[1 .. 2]);

				return token;
			}

		case '\x5D': .. case '\x60': // ]^_`
		case '\x61': .. case '\x7A': // 'a' .. 'z'
			return this.makeTextToken();

		case '\x7B': // '{'
			return this.lexBraceBlockOpening();

		case '\x7C': // '|'
			return this.makeTextToken();

		case '\x7D': // '}'
			return this.makeToken(TokenType.braceBlockClosing, 1);

		case '\x7E': // '~'
			return this.makeTextToken();

		case '\x7F':
			return Token(TokenType.error, errorMsgBinaryFile);

		case '\x80': .. case '\xFF': // Unicode
			return this.makeTextToken();

		default:
			assert(false, "unreachable");
		}

		assert(false, "unreachable");
	}

	private Token lexDash() {
		// "-<EOF>"
		if (this.isOnFinalChar) {
			return this.makeTextToken();
		}

		// "-}"
		if (_source[1] == '}') {
			return this.makeToken(TokenType.braceBlockClosingWsCtrl, 2);
		}

		// "---"
		enum metaBlockTag = "---";
		if (_source.scanMatch!metaBlockTag()) {
			if (_source.length <= metaBlockTag.length) {
				return this.makeError(errorMsgUnterminatedMetaBlock, _source.length);
			}

			// one-liner?
			if (!(_source[metaBlockTag.length + 1].isWhite)) {
				const idxLF = _source.scanFor('\n');

				const data = _source[metaBlockTag.length .. idxLF];
				auto token = Token(TokenType.metaBlock, data, _location);

				_location.advance(_source[0 .. idxLF]);
				_source = _source[idxLF .. $];

				return token;
			}

			const offsetClosing = _source[metaBlockTag.length .. $].scanFor!metaBlockTag();
			if (offsetClosing < 0) {
				return this.makeError(errorMsgMissingClosingTagMetaBlock, _source.length);
			}
			const idxClosing = metaBlockTag.length + offsetClosing;
			const idxBlockEnd = idxClosing + metaBlockTag.length;

			const data = _source[metaBlockTag.length .. idxClosing];
			auto token = Token(TokenType.metaBlock, data, _location);

			_location.advance(_source[0 .. idxBlockEnd]);
			_source = _source[idxBlockEnd .. $];

			return token;
		}

		// "-<?>"
		return this.makeTextToken();
	}

	private Token lexBraceBlockOpening() {
		// "{<EOF>"
		if (this.isOnFinalChar) {
			return this.makeToken(TokenType.braceBlockOpening, 1);
		}

		const bool isBlock = _source.scanMatch!"{{{"();
		if (!isBlock) {
			if (_source[1] == '-') {
				return this.makeToken(TokenType.braceBlockOpeningWsCtrl, 2);
			}
			return this.makeToken(TokenType.braceBlockOpening, 1);
		}

		const offsetBlockEnd = _source[3 .. $].scanFor!"}}}"() + 3; // 3: "{{{"
		if (offsetBlockEnd < 0) {
			return this.makeError(errorMsgMissingClosingTagEmbeddedAppBlock, _source.length);
		}
		const idxBlockEnd = offsetBlockEnd + 3; // 3: "}}}"

		const offsetDataStart = scanWhitespaceUntilLineFeed(_source[3 .. $]); // 3: "{{{"
		if (offsetDataStart < 0) {
			return this.makeError(errorMsgMissingLineBreakOpeningTagEmbeddedAppBlock, idxBlockEnd);
		}
		const idxDataStart = offsetDataStart + 4; // 4: "{{{" ~ "\n"

		const offsetDataEnd = scanWhitespaceUntilLineFeedReverse(_source[idxDataStart .. offsetBlockEnd]);
		if (offsetDataEnd < 0) {
			return this.makeError(errorMsgMissingLineBreakClosingTagEmbeddedAppBlock, idxBlockEnd);
		}
		const idxDataEnd = offsetDataEnd + 4; // 4: "\n" ~ "}}}"

		hstring data = _source[idxDataStart .. idxDataEnd];
		auto token = Token(
			TokenType.embeddedAppBlock,
			data,
			_location,
		);

		_location.line += countLineFeeds(_source[0 .. idxBlockEnd]);
		_location.column = offsetBlockEnd - offsetDataEnd;
		_source = _source[idxBlockEnd .. $];
		return token;
	}

	private Token lexSlash() {
		// "/<EOF>"
		if (this.isOnFinalChar) {
			return this.makeTextToken();
		}

		switch (_source[1]) {
		default:
			return this.makeTextToken(1);

		case '/': /* "//" */ {
				auto idx = _source[1 .. $].scanFor('\n');
				if (idx <= 0) {
					return this.makeTextToken();
				}

				this.advanceLocationToNextLine();
				return this.makeToken(TokenType.comment, idx);
			}

		case '*': /* "/*" */ {
				enum idxDataStart = 2;

				const offsetBlockEnd = _source[idxDataStart .. $].scanFor!"*/"();
				if (offsetBlockEnd < 0) {
					return this.makeError(errorMsgMissingClosingTagBlockComment, _source.length);
				}
				const idxDataEnd = offsetBlockEnd + 2; // 2: "/*"
				const idxBlockEnd = offsetBlockEnd + 4; // 4: "/*" ~ "*/"

				hstring data = _source[idxDataStart .. idxDataEnd];
				auto token = Token(
					TokenType.comment,
					data,
					_location,
				);

				_location.advance(_source[0 .. idxBlockEnd]);
				_source = _source[idxBlockEnd .. $];

				return token;
			}

		case '+': /* "/+" */ {
				enum openingTag = "/+";
				enum closingTag = "+/";

				enum idxDataStart = openingTag.length;

				ptrdiff_t idx = idxDataStart;

				ptrdiff_t counter = 1;
				while ((_source.length - idx) >= closingTag.length) {
					auto data = _source[idx .. $];
					if (data[0 .. closingTag.length] == closingTag) {
						--counter;
						idx += closingTag.length;
						if (counter == 0) {
							break;
						}
						continue;
					}

					if (data[0 .. openingTag.length] == openingTag) {
						++counter;
						idx += openingTag.length;
						continue;
					}

					++idx;
				}

				if (counter > 0) {
					return this.makeError(errorMsgMissingClosingTagBlockCommentNested, _source.length);
				}

				const idxDataEnd = idx - closingTag.length;

				const data = _source[idxDataStart .. idxDataEnd];
				auto token = Token(TokenType.comment, data, _location);

				_location.advance(_source[0 .. idx]);
				_source = _source[idx .. $];

				return token;
			}
		}
	}
}

private {

@safe pure nothrow @nogc:

	enum ScanError : ptrdiff_t {
		endOfData = -1,
		invalidData = -2,
	}

	ptrdiff_t countLineFeeds(hstring data) {
		ptrdiff_t counter = 0;

		foreach (c; data) {
			if (c == '\n') {
				++counter;
			}
		}

		return counter;
	}

	void advance(ref Location loc, hstring data) {
		foreach (c; data) {
			if (c == '\n') {
				++loc.line;
				loc.column = 1;
			} else {
				loc.column += 1;
			}
		}
	}

	ptrdiff_t scanEndOfText(hstring data) {
		foreach (idx, c; data) {
			switch (c) {
			case '!': .. case '.':
			case '0': .. case '[':
			case ']': .. case 'z':
			case '|':
			case '~':
			case '\x80': .. case '\xFF':
				continue;

			default:
				return idx;
			}
		}

		return data.length;
	}

	ptrdiff_t scanEndOfWhitespace(hstring data) {
		foreach (idx, c; data) {
			switch (c) {

			case ' ':
			case '\x09':
			case '\x0A': .. case '\x0D':
				continue;

			default:
				return idx;
			}
		}

		return data.length;
	}

	ptrdiff_t scanEndOfWhitespace(hstring data, ref ptrdiff_t line, ref ptrdiff_t column) {
		foreach (idx, c; data) {
			switch (c) {

			case '\x0A':
				++line;
				column = 1;
				continue;

			case ' ':
			case '\x09':
			case '\x0B': .. case '\x0D':
				++column;
				continue;

			default:
				return idx;
			}
		}

		return data.length;
	}

	bool scanMatchNext(hstring data, char needle) {
		if (data.length <= 1) {
			return false;
		}

		return (data[1] == needle);
	}

	bool scanMatch(string needle)(hstring data) {
		if (data.length < needle.length) {
			return false;
		}

		return (data[0 .. needle.length] == needle);
	}

	ptrdiff_t scanFor(hstring data, char needle) {
		foreach (idx, c; data) {
			if (c == needle) {
				return idx;
			}
		}

		return ScanError.endOfData;
	}

	ptrdiff_t scanFor(string needle)(hstring data) {
		size_t idx = 0;
		while (data.length >= needle.length) {
			if (data[0 .. needle.length] == needle) {
				return idx;
			}

			data = data[1 .. $];
			++idx;
		}

		return ScanError.endOfData;
	}

	ptrdiff_t scanWhitespaceUntilLineFeed(hstring data) {
		foreach (idx, c; data) {
			if (c == '\n') {
				return idx;
			}
			if (!c.isWhite) {
				return ScanError.invalidData;
			}
		}

		return ScanError.endOfData;
	}

	ptrdiff_t scanWhitespaceUntilLineFeedReverse(hstring data) {
		foreach_reverse (idx, c; data) {
			if (c == '\n') {
				return idx;
			}
			if (!c.isWhite) {
				return ScanError.invalidData;
			}
		}

		return ScanError.endOfData;
	}
}
