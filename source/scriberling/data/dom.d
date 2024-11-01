/++
	DOM tree
 +/
module scriberling.data.dom;

import scriberling.data.html;
import scriberling.site.config;
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
class Node {

	private {
		Node _parent = null;
	}

	///
	inout(Node) parent() inout @safe pure nothrow @nogc {
		return _parent;
	}

	///
	abstract void compile(const SiteConfig siteConfig) @safe pure;
	///
	abstract void toHTML(Sink sink) @safe;
}

///
class Element : Node {
	public {
		hstring name;
		bool isVoid = false;
		hstring[hstring] attributes;
	}

	private {
		Node[] _children;
		bool _compiled = false;
	}

@safe:

	public final {
		inout(Node)[] children() inout pure nothrow @nogc {
			return _children;
		}

		void appendChild(Node node) pure nothrow {
			_children ~= node;
			node._parent = this;
		}
	}

	///
	final override void compile(const SiteConfig siteConfig) pure {
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
	override void toHTML(Sink sink) {
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

final class EmbeddedAppNode : Node {

	public {
		hstring data;
		Location location;
	}

	///
	override void compile(const SiteConfig) pure {
		return;
	}

	override void toHTML(Sink sink) {
		// TODO: Implement
		sink.put("<div>Error: Feature not implemented.</div>");
	}
}

///
final class TextNode : Node {
	public {
		hstring content;
	}

@safe:

	///
	override void compile(const SiteConfig) pure {
		return;
	}

	///
	override void toHTML(Sink sink) {
		foreach (c; htmlEscape!(EscapeCharacterSelection.content)(content)) {
			sink.put(c);
		}
	}
}

///
final class WhitespaceNode : Node {

@safe:

	///
	override void compile(const SiteConfig) pure {
		return;
	}

	///
	override void toHTML(Sink sink) {
		sink.put(lineBreak);
	}
}
