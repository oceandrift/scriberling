/++
	DOM tree
 +/
module scriberling.data.dom;

import scriberling.data.html;
import scriberling.site.config;
import scriberling.types;
import std.range : isOutputRange;

///
public import scriberling.site.config : SiteConfig;

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
		Element _parent = null;
	}

	///
	inout(Element) parent() inout @safe pure nothrow @nogc {
		return _parent;
	}

	///
	abstract void analyze(const SiteConfig siteConfig) @safe pure;
	///
	abstract void compile(Sink sink) @safe;
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
	final override void analyze(const SiteConfig siteConfig) pure {
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
			child.analyze(siteConfig);
		}
	}

	protected void compileElement(const SiteConfig siteConfig) pure {
		this.compileElementDefaults(siteConfig);
	}

	///
	override void compile(Sink sink) {
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
				child.compile(sink);
			}

			if (name !is null) {
				sink.put(htmlClosingTagStart);
				sink.put(this.name);
				sink.put(htmlTagEnd);
			}
		}
	}
}

@safe pure {

	///
	bool hasChildren(const Element element) {
		return (element.children.length > 0);
	}

	void replaceChild(Element element, Node needle, Node substitute) {
		foreach (ref child; element._children) {
			if (child is needle) {
				child = substitute;
				return;
			}
		}
	}
}

///
final class RawNode : Node {

	public {
		hstring innerHTML;
	}

@safe:

	///
	override void analyze(const SiteConfig siteConfig) {
		return;
	}

	///
	override void compile(Sink sink) {
		sink.put(this.innerHTML);
	}
}

///
final class TextNode : Node {
	public {
		hstring content;
	}

@safe:

	///
	override void analyze(const SiteConfig) pure {
		return;
	}

	///
	override void compile(Sink sink) {
		foreach (c; htmlEscape!(EscapeCharacterSelection.content)(content)) {
			sink.put(c);
		}
	}
}

///
final class WhitespaceNode : Node {

@safe:

	///
	override void analyze(const SiteConfig) pure {
		return;
	}

	///
	override void compile(Sink sink) {
		sink.put(lineBreak);
	}
}
