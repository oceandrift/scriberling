module scriberling.formats.sdf.parser;

import scriberling.formats.sdf.lexer;
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

class SDFNode {
}

class SDFElement : SDFNode {
}

final class SDFSDFElement : SDFElement {
	hstring typeName;
	SDFNode[] children;
	WhitespaceControl whitespaceControl = WhitespaceControl.none;
}

final class SDFTextNode : SDFNode {
	hstring content;
}

final class SDFWhitespaceNode : SDFNode {
}

final class SDFEmbeddedAppElement : SDFElement {
	hstring data;
	Location location;
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

SDFSDFElement parseSDF(hstring data) {
	return parseSDF(SDFLexer(data));
}

SDFSDFElement parseSDF(SDFLexer lexer) {
	auto root = new SDFSDFElement();
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

SDFNode[] chompWhitespaceReverse(SDFNode[] list) {
	while (list.length > 0) {
		auto node = cast(SDFWhitespaceNode) list[$ - 1];
		if (node is null) {
			return list;
		}

		list = list[0 .. ($ - 1)];
	}

	return list;
}

void parseElementContent(ref SDFLexer lexer, SDFSDFElement element) {
	while (!lexer.empty) {
		switch (lexer.front.type) {
		case TokenType.text:
		case TokenType.escapeSeq: {
				auto node = new SDFTextNode();
				node.content = lexer.front.data;
				element.children ~= node;

				lexer.popFront();
				break;
			}

		case TokenType.whitespace:
			element.children ~= new SDFWhitespaceNode();
			lexer.popFront();
			break;

		case TokenType.identifier:
			element.children ~= parseElement(lexer);
			break;

		case TokenType.metaBlock:
			parseMetaBlock(lexer, element);
			break;

		case TokenType.braceBlockClosingWsCtrl:
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

SDFElement parseElement(ref SDFLexer lexer) {
	return parseElementSignature(lexer);
}

SDFElement parseElementSignature(ref SDFLexer lexer) {
	if (lexer.front.type != TokenType.identifier) {
		static immutable expected = [TokenType.identifier];
		throw new SDFUnexpectedTokenException(lexer.front, expected);
	}

	const typeName = lexer.front.data;
	lexer.popFront();

	return parseElementOpening(lexer, typeName);
}

SDFElement parseElementOpening(ref SDFLexer lexer, hstring typeName) {
	lexer.skipWhitespace();

	switch (lexer.front.type) {

	case TokenType.braceBlockOpeningWsCtrl: {
			auto element = new SDFSDFElement();
			element.typeName = typeName;
			element.whitespaceControl |= WhitespaceControl.left;
			lexer.popFront();
			parseElementContent(lexer, element);
			return element;
		}

	case TokenType.braceBlockOpening: {
			auto element = new SDFSDFElement();
			element.typeName = typeName;
			lexer.popFront();
			parseElementContent(lexer, element);
			return element;
		}

	case TokenType.embeddedAppBlock:
		return parseEmbeddedAppBlock(lexer);

	default:
		static immutable expected = [TokenType.braceBlockOpening];
		throw new SDFUnexpectedTokenException(lexer.front, expected);
	}
}

void parseMetaBlock(ref SDFLexer lexer, SDFElement element) {
	// TODO
	lexer.popFront();
}

SDFEmbeddedAppElement parseEmbeddedAppBlock(ref SDFLexer lexer) {
	if (lexer.front.type != TokenType.embeddedAppBlock) {
		static immutable expected = [TokenType.embeddedAppBlock];
		throw new SDFUnexpectedTokenException(lexer.front, expected);
	}

	auto element = new SDFEmbeddedAppElement();
	element.data = lexer.front.data;
	element.location = lexer.front.location;

	lexer.popFront();
	return element;
}
