/++
	DOM tree
 +/
module scriberling.dom;

import scriberling.html;
import scriberling.siteconfig;
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
static immutable attributeKeyValueSeparatorAndValueStart = "=\"";
///
static immutable attributeValueEnd = '"';

private void printAttribute(Sink sink, hstring key, hstring value) @safe {
	sink.put(key);
	sink.put(attributeKeyValueSeparatorAndValueStart);
	sink.put(attributeValueEnd);
	foreach (c; htmlEscape!(EscapeCharacterSelection.attributeDoubleQuotesOnly)(value)) {
		sink.put(value);
	}
	sink.put(attributeValueEnd);
}

private void printAttributes(Sink sink, const hstring[hstring] attributes) @safe {
	foreach (key, value; attributes) {
		sink.printAttribute(key, value);
	}
}

///
interface Node {
	///
	void compile(const SiteConfig siteConfig) @safe pure;
	///
	void toHTML(Sink sink) @safe;
}

class Element : Node {
	public {
		hstring name;
		bool isVoid = false;
		Node[] children;
		hstring[hstring] attributes;
	}

	private {
		bool _compiled = false;
	}

@safe:

	///
	final void compile(const SiteConfig siteConfig) pure {
		if (_compiled) {
			return;
		}

		compileElement(siteConfig);
		_compiled = true;
	}

	final protected void compileElementDefaults(const SiteConfig siteConfig) pure {
		auto voidElementInfo = name in siteConfig.voidElements;
		if (voidElementInfo !is null) {
			this.isVoid = *voidElementInfo;
		}

		foreach (child; children) {
			child.compile(siteConfig);
		}
	}

	protected void compileElement(const SiteConfig siteConfig) pure {
		this.compileElementDefaults(siteConfig);
	}

	///
	void toHTML(Sink sink) {
		if (name !is null) {
			sink.put(htmlOpeningTagStart);
			sink.put(this.name);
			sink.printAttributes(this.attributes);
			sink.put(htmlTagEnd);
		}

		// TODO: Ignore whitespace children
		const printClosingTag = (!this.isVoid || this.hasChildren);

		if (printClosingTag) {
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

///
bool hasChildren(const Element element) @safe {
	return (element.children.length > 0);
}

///
final class TextNode : Node {
	public {
		hstring content;
	}

@safe:

	///
	void compile(const SiteConfig) pure {
		return;
	}

	///
	void toHTML(Sink sink) {
		foreach (c; htmlEscape!(EscapeCharacterSelection.content)(content)) {
			sink.put(c);
		}
	}
}

///
final class WhitespaceNode : Node {

@safe:

	///
	void compile(const SiteConfig) pure {
		return;
	}

	///
	void toHTML(Sink sink) {
		sink.put(lineBreak);
	}
}
