module scriberling.formats.sdf.parser;

import scriberling.data.dom;
import scriberling.formats.sdf.lexer;
import scriberling.formats.embedded;
import scriberling.site.config;
import scriberling.types;
import std.conv : to;
import std.sumtype;

private alias TokenType = SDFTokenType;
private alias Token = SDFToken;

enum WhitespaceControl {
	// dfmt off
	none  = 0b_00,
	left  = 0b_01,
	right = 0b_10,
	both  = (left | right),
	// dfmt on
}

class SDFElement : Element {
	WhitespaceControl whitespaceControl = WhitespaceControl.none;

	///
	override void compileElement(const SiteConfig siteConfig) pure {
		this.compileElementDefaults(siteConfig);
		return;
	}
}

class SDFParserException : Exception {
	public {
		Location location;
	}

@nogc @safe pure nothrow:
	public this(string msg, Location location, string file = __FILE__, size_t line = __LINE__) {
		super(msg, file, line);
		this.location = location;
	}
}

final class SDFUnexpectedTokenException : SDFParserException {
	public {
		SDFToken got;
		const(SDFTokenType)[] expected;
	}

@safe pure:

	public this(SDFToken got, const(SDFTokenType)[] expected, string file = __FILE__, size_t line = __LINE__) {
		string msg = "Unexpected `" ~ got.type.to!string ~ "` token, expected ";
		if (expected.length == 0) {
			msg ~= "something else.";
		} else {
			foreach (idx, type; expected) {
				if (idx == 0) {
					msg ~= '`';
				} else {
					msg ~= "` or `";
				}

				msg ~= type.to!string;
			}
			msg ~= "`.";
		}

		super(msg, got.location, file, line);

		this.got = got;
		this.expected = expected;
	}
}

@safe pure:

SDFElement parseSDF(hstring data) {
	return parseSDF(SDFLexer(data));
}

SDFElement parseSDF(SDFLexer lexer) {
	auto root = new SDFElement();
	parseElementContent(lexer, root);

	return root;
}

private:

void skipWhitespace(ref SDFLexer lexer) {
	while (!lexer.empty) {
		if (lexer.front.type != TokenType.whitespace) {
			return;
		}
		lexer.popFront();
	}
}

Node[] chompWhitespaceReverse(Node[] list) {
	while (list.length > 0) {
		auto node = cast(WhitespaceNode) list[$ - 1];
		if (node is null) {
			return list;
		}

		list = list[0 .. ($ - 1)];
	}

	return list;
}

void parseElementContent(ref SDFLexer lexer, SDFElement element) {
	while (!lexer.empty) {
		switch (lexer.front.type) {
		case TokenType.text:
		case TokenType.escapeSeq: {
				auto node = new TextNode();
				node.content = lexer.front.data;
				element.appendChild(node);

				lexer.popFront();
				break;
			}

		case TokenType.whitespace:
			element.appendChild(new WhitespaceNode());
			lexer.popFront();
			break;

		case TokenType.identifier:
			element.appendChild(parseElement(lexer));
			break;

		case TokenType.metaBlock:
			parseMetaBlock(lexer, element);
			break;

		case TokenType.braceBlockClosingWsCtrlOff:
			element.whitespaceControl &= ~WhitespaceControl.right;
			goto case TokenType.braceBlockClosing;

		case TokenType.braceBlockClosingWsCtrlOn:
			element.whitespaceControl |= WhitespaceControl.right;
			goto case TokenType.braceBlockClosing;

		case TokenType.braceBlockClosing:
			lexer.popFront();
			return;

		case TokenType.comment:
			lexer.popFront();
			break;

		default: {
				static immutable expected = [
					TokenType.braceBlockClosing,
					TokenType.identifier,
					TokenType.metaBlock,
					TokenType.text,
				];
				throw new SDFUnexpectedTokenException(lexer.front, expected);
			}
		}
	}
}

Node parseElement(ref SDFLexer lexer) {
	return parseElementSignature(lexer);
}

Node parseElementSignature(ref SDFLexer lexer) {
	if (lexer.front.type != TokenType.identifier) {
		static immutable expected = [TokenType.identifier];
		throw new SDFUnexpectedTokenException(lexer.front, expected);
	}

	const name = lexer.front.data;
	lexer.popFront();

	return parseElementOpening(lexer, name);
}

Node parseElementOpening(ref SDFLexer lexer, hstring name) {
	lexer.skipWhitespace();

	switch (lexer.front.type) {

	case TokenType.braceBlockOpeningWsCtrlOff: {
			auto element = new SDFElement();
			element.name = name;
			element.whitespaceControl &= ~WhitespaceControl.left;
			lexer.popFront();
			parseElementContent(lexer, element);
			return element;
		}

	case TokenType.braceBlockOpeningWsCtrlOn: {
			auto element = new SDFElement();
			element.name = name;
			element.whitespaceControl |= WhitespaceControl.left;
			lexer.popFront();
			parseElementContent(lexer, element);
			return element;
		}

	case TokenType.braceBlockOpening: {
			auto element = new SDFElement();
			element.name = name;
			lexer.popFront();
			parseElementContent(lexer, element);
			return element;
		}

	case TokenType.embeddedAppBlock:
		return parseEmbeddedAppBlock(lexer, name);

	default:
		static immutable expected = [TokenType.braceBlockOpening];
		throw new SDFUnexpectedTokenException(lexer.front, expected);
	}
}

void parseMetaBlock(ref SDFLexer lexer, SDFElement element) {
	// TODO
	lexer.popFront();
}

EmbeddedAppNode parseEmbeddedAppBlock(ref SDFLexer lexer, hstring name) {
	if (lexer.front.type != TokenType.embeddedAppBlock) {
		static immutable expected = [TokenType.embeddedAppBlock];
		throw new SDFUnexpectedTokenException(lexer.front, expected);
	}

	auto node = new EmbeddedAppNode();
	node.app = name;
	node.data = lexer.front.data;
	node.location = lexer.front.location;

	lexer.popFront();
	return node;
}
