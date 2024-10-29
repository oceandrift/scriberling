/++
	DOM tree
 +/
module scriberling.dom;

import scriberling.html;
import scriberling.types;
import std.range : isOutputRange;

///
interface Sink {
	///
	void put(char data) @safe;
	///
	void put(hstring data) @safe;
}

static assert(isOutputRange!(Sink, char));
static assert(isOutputRange!(Sink, hstring));

///
static immutable htmlOpeningTagStart = '<';
///
static immutable htmlClosingTagStart = "</";
///
static immutable htmlTagEnd = '>';
///
static immutable lineBreak = '\n';

///
interface Node {
	///
	void toHTML(Sink sink) @safe;
}

class Element : Node {
	hstring name;
	bool isVoid = false;
	Node[] children;
	hstring[hstring] attributes;

	///
	void toHTML(Sink sink) {
		if (name !is null) {
			sink.put(htmlOpeningTagStart);
			sink.put(this.name);
			sink.put(htmlTagEnd);
		}

		if (!this.isVoid) {

			foreach (child; this.children) {
				child.toHTML(sink);
			}

			if (name !is null) {
				sink.put(htmlClosingTagStart);
				sink.put(this.name);
				sink.put(htmlTagEnd);
			}
		}
	}
}

final class TextNode : Node {
	hstring content;

	void toHTML(Sink sink) {
		foreach (c; htmlEscape(content)) {
			sink.put(c);
		}
	}
}

final class WhitespaceNode : Node {
	void toHTML(Sink sink) {
		sink.put(lineBreak);
	}
}
