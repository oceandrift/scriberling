module scriberling.formats.md.parser;

import std.conv : to;
import scriberling.data.dom;
import scriberling.data.html;
import scriberling.data.unicode;
import scriberling.types;
import md4c;

// dfmt off
private enum md4cFlags = (
	  MD_FLAG_TABLES
	| MD_FLAG_STRIKETHROUGH
	| MD_FLAG_PERMISSIVEURLAUTOLINKS
);
// dfmt on

private {

	string toString(MD_ALIGN a) @safe pure nothrow @nogc {
		static immutable left = "left";
		static immutable center = "center";
		static immutable right = "right";

		final switch (a) {
		case MD_ALIGN_DEFAULT:
			return null;
		case MD_ALIGN_LEFT:
			return left;
		case MD_ALIGN_CENTER:
			return center;
		case MD_ALIGN_RIGHT:
			return right;
		}
	}

	hstring toString(const MD_ATTRIBUTE a) @trusted pure nothrow {
		import std.array : appender;

		const data = a.text[0 .. a.size];

		// Single element?
		if (a.size == a.substr_offsets[1]) {
			return data;
		}

		auto result = appender!hstring();

		ptrdiff_t idxSegment = 0;
		while (true) {
			const segmentType = a.substr_types[idxSegment];
			const idxStart = a.substr_offsets[idxSegment];
			const idxEnd = a.substr_offsets[++idxSegment];

			auto segmentValue = data[idxStart .. idxEnd];

			if (segmentType == MD_TEXT_ENTITY) {
				result ~= htmlDecodeEntity(segmentValue);
			} else {
				result ~= segmentValue;
			}

			if (idxEnd == a.size) {
				break;
			}
		}

		return result[];
	}

	struct TextCollector {
		import std.array : appender, Appender;

		private {
			Appender!hstring _data;
			bool _active = false;

			MD_SPANTYPE _type;
			ptrdiff_t _currentNestingLevel;

			hstring _targetAttribute;
		}

	@safe pure nothrow:

		bool isActive() @nogc {
			return _active;
		}

		void enterSpan(MD_SPANTYPE type) @nogc {
			if (type == _type) {
				++_currentNestingLevel;
			}
		}

		void leaveSpan(MD_SPANTYPE type) @nogc {
			if (type == _type) {
				--_currentNestingLevel;
			}
		}

		void activate(MD_SPANTYPE type, hstring targetAttribute) {
			_type = type;
			_targetAttribute = targetAttribute;
			this.activateImpl();
		}

		void deactivate() {
			if (_currentNestingLevel != 0) {
				assert(false, "Deactivating a not yet done TextCollector.");
			}

			_active = false;
		}

		private void activateImpl() {
			_data = appender!hstring();
			_active = true;
			_currentNestingLevel = 1;
		}

		bool isDone() @nogc {
			return (_currentNestingLevel == 0);
		}

		void put(hstring text) {
			_data.put(text);
		}

		hstring data() @nogc {
			return _data[];
		}

		hstring targetAttribute() @nogc {
			return _targetAttribute;
		}
	}

	struct MD4CAdapter {

		public {
			Element root = null;
			Element current = null;
		}

		private {
			TextCollector _textCollector;
		}

	@safe pure:

		void pushElement(hstring name) {
			auto element = new Element();
			element.name = name;

			if (this.current is null) {
				if (this.root !is null) {
					auto newRoot = new Element();
					newRoot.name = null;
					newRoot.appendChild(this.root);
					newRoot.appendChild(element);
					this.root = newRoot;
				} else {
					this.root = element;
				}
			} else {
				this.current.appendChild(element);
			}

			this.current = element;
		}

		void popElement(hstring name) {
			if (this.current is null) {
				assert(false, "Tree violation by markdown parser.");
			}

			if (this.current.name != name) {
				assert(false, "Tree violation by markdown parser.");
			}

			this.current = this.current.parent;
		}

	@system pure:

		void enterBlock(MD_BLOCKTYPE type, void* detail) {

			final switch (type) {
			case MD_BLOCK_DOC:
				this.pushElement(null);
				break;

			case MD_BLOCK_QUOTE:
				this.pushElement("blockquote");
				break;

			case MD_BLOCK_UL:
				this.pushElement("ul");
				break;

			case MD_BLOCK_OL:
				this.pushElement("ol");
				break;

			case MD_BLOCK_LI:
				this.pushElement("li");
				break;

			case MD_BLOCK_HR:
				this.pushElement("hr");
				break;

			case MD_BLOCK_H: {
					const hDetail = cast(MD_BLOCK_H_DETAIL*) detail;
					const elementName = "h" ~ hDetail.level.to!string;
					this.pushElement(elementName);
				}
				break;

			case MD_BLOCK_CODE:
				this.pushElement("pre");
				break;

			case MD_BLOCK_HTML:
				this.pushElement(null);
				break;

			case MD_BLOCK_P:
				this.pushElement("p");
				break;

			case MD_BLOCK_TABLE: {
					//const tableDetail = cast(MD_BLOCK_TABLE_DETAIL*) detail;
					this.pushElement("table");
				}
				break;

			case MD_BLOCK_THEAD:
				this.pushElement("thead");
				break;

			case MD_BLOCK_TBODY:
				this.pushElement("tbody");
				break;

			case MD_BLOCK_TR:
				this.pushElement("tr");
				break;

			case MD_BLOCK_TH: {
					const thDetail = cast(MD_BLOCK_TD_DETAIL*) detail;
					this.pushElement("th");

					// `align` is a keyword in D.
					const alignValue = __traits(getMember, *thDetail, "align");
					this.current.attributes["align"] = alignValue.toString();
				}
				break;

			case MD_BLOCK_TD: {
					const tdDetail = cast(MD_BLOCK_TD_DETAIL*) detail;
					this.pushElement("td");

					// `align` is a keyword in D.
					const alignValue = __traits(getMember, *tdDetail, "align");
					this.current.attributes["align"] = alignValue.toString();
				}
				break;
			}
		}

		void leaveBlock(MD_BLOCKTYPE type, void* detail) {
			final switch (type) {
			case MD_BLOCK_DOC:
				this.popElement(null);
				break;

			case MD_BLOCK_QUOTE:
				this.popElement("blockquote");
				break;

			case MD_BLOCK_UL:
				this.popElement("ul");
				break;

			case MD_BLOCK_OL:
				this.popElement("ol");
				break;

			case MD_BLOCK_LI:
				this.popElement("li");
				break;

			case MD_BLOCK_HR:
				this.popElement("hr");
				break;

			case MD_BLOCK_H: {
					const hDetail = cast(MD_BLOCK_H_DETAIL*) detail;
					const elementName = "h" ~ hDetail.level.to!string;
					this.popElement(elementName);
				}
				break;

			case MD_BLOCK_CODE:
				this.popElement("pre");
				break;

			case MD_BLOCK_HTML:
				this.popElement(null);
				break;

			case MD_BLOCK_P:
				this.popElement("p");
				break;

			case MD_BLOCK_TABLE:
				this.popElement("table");
				break;

			case MD_BLOCK_THEAD:
				this.popElement("thead");
				break;

			case MD_BLOCK_TBODY:
				this.popElement("tbody");
				break;

			case MD_BLOCK_TR:
				this.popElement("tr");
				break;

			case MD_BLOCK_TH:
				this.popElement("th");
				break;

			case MD_BLOCK_TD:
				this.popElement("td");
				break;
			}
		}

		void enterSpan(MD_SPANTYPE type, void* detail) {
			if (_textCollector.isActive) {
				_textCollector.enterSpan(type);
				return;
			}

			final switch (type) {
			case MD_SPAN_EM:
				this.pushElement("em");
				break;

			case MD_SPAN_STRONG:
				this.pushElement("strong");
				break;

			case MD_SPAN_A: {
					const aDetail = cast(MD_SPAN_A_DETAIL*) detail;
					this.pushElement("a");

					const href = aDetail.href.toString();
					if (href !is null) {
						this.current.attributes["href"] = href;
					}

					const title = aDetail.title.toString();
					if (title !is null) {
						this.current.attributes["title"] = title;
					}
				}
				break;

			case MD_SPAN_IMG: {
					const imgDetail = cast(MD_SPAN_IMG_DETAIL*) detail;
					this.pushElement("img");

					const src = imgDetail.src.toString();
					if (src !is null) {
						this.current.attributes["src"] = src;
					}

					const title = imgDetail.title.toString();
					if (title !is null) {
						this.current.attributes["title"] = title;
					}

					_textCollector.activate(MD_SPAN_IMG, "alt");
				}
				break;

			case MD_SPAN_CODE:
				this.pushElement("code");
				break;

			case MD_SPAN_DEL:
				this.pushElement("del");
				break;

			case MD_SPAN_LATEXMATH:
			case MD_SPAN_LATEXMATH_DISPLAY:
				assert(false, "LaTeX support not implemented.");

			case MD_SPAN_WIKILINK:
				assert(false, "Wiki links support not implemented.");

			case MD_SPAN_U:
				this.pushElement("u");
				break;
			}
		}

		void leaveSpan(MD_SPANTYPE type, void* detail) {
			if (_textCollector.isActive) {
				_textCollector.leaveSpan(type);

				if (!_textCollector.isDone) {
					return;
				}

				this.current.attributes[_textCollector.targetAttribute] = _textCollector.data;
				_textCollector.deactivate();
			}

			final switch (type) {
			case MD_SPAN_EM:
				this.popElement("em");
				break;

			case MD_SPAN_STRONG:
				this.popElement("strong");
				break;

			case MD_SPAN_A:
				this.popElement("a");
				break;

			case MD_SPAN_IMG:
				// TODO: asadsfas
				this.popElement("img");
				break;

			case MD_SPAN_CODE:
				this.popElement("code");
				break;

			case MD_SPAN_DEL:
				this.popElement("del");
				break;

			case MD_SPAN_LATEXMATH:
			case MD_SPAN_LATEXMATH_DISPLAY:
				assert(false, "LaTeX support not implemented.");

			case MD_SPAN_WIKILINK:
				assert(false, "Wiki links support not implemented.");

			case MD_SPAN_U:
				this.popElement("u");
				break;
			}
		}

		void text(MD_TEXTTYPE type, hstring text) {
			if (_textCollector.isActive) {
				return textImplCollector(type, text);
			}

			return textImplRegular(type, text);
		}

		private void textImplRegular(MD_TEXTTYPE type, hstring text) {
			final switch (type) {

			case MD_TEXT_NORMAL:
			case MD_TEXT_CODE: {
					auto node = new TextNode();
					node.content = text;
					this.current.appendChild(node);
				}
				break;

			case MD_TEXT_NULLCHAR: {
					auto node = new TextNode();
					node.content = replacementCharacterString;
					this.current.appendChild(node);
				}
				break;

			case MD_TEXT_BR: {
					auto node = new Element();
					node.name = "br";
					this.current.appendChild(node);
				}
				break;

			case MD_TEXT_SOFTBR: {
					auto node = new WhitespaceNode();
					this.current.appendChild(node);
				}
				break;

			case MD_TEXT_ENTITY: {
					// Try to resolve the entity.
					const entity = htmlDecodeEntity(text);

					if (entity is null) {
						// Entity is probably invalid. Pass it through as-is.
						auto node = new RawNode();
						node.innerHTML = text;
						this.current.appendChild(node);
					} else {
						auto node = new TextNode();
						node.content = entity;
						this.current.appendChild(node);
					}
				}
				break;

			case MD_TEXT_HTML: {
					auto node = new RawNode();
					node.innerHTML = text;
					this.current.appendChild(node);
				}
				break;

			case MD_TEXT_LATEXMATH:
				assert(false, "LaTeX support not implemented.");
			}
		}

		private void textImplCollector(MD_TEXTTYPE type, hstring text) {
			final switch (type) {

			case MD_TEXT_NORMAL:
			case MD_TEXT_CODE:
			case MD_TEXT_HTML:
				_textCollector.put(text);
				break;

			case MD_TEXT_NULLCHAR:
				_textCollector.put(replacementCharacterString);
				break;

			case MD_TEXT_BR:
				_textCollector.put(lineBreakString);
				break;

			case MD_TEXT_SOFTBR:
				_textCollector.put(spaceString);
				break;

			case MD_TEXT_ENTITY: {
					// Try to resolve the entity.
					const entity = htmlDecodeEntity(text);

					if (entity is null) {
						_textCollector.put(text);
					} else {
						_textCollector.put(entity);
					}
				}
				break;

			case MD_TEXT_LATEXMATH:
				assert(false, "LaTeX support not implemented.");
			}
		}
	}

extern (C):

	int md4ca_enter_block(MD_BLOCKTYPE type, void* detail, void* userdata) @system {
		auto md4cA = cast(MD4CAdapter*) userdata;
		md4cA.enterBlock(type, detail);
		return 0;
	}

	int md4ca_leave_block(MD_BLOCKTYPE type, void* detail, void* userdata) @system {
		auto md4cA = cast(MD4CAdapter*) userdata;
		md4cA.leaveBlock(type, detail);
		return 0;
	}

	int md4ca_enter_span(MD_SPANTYPE type, void* detail, void* userdata) @system {
		auto md4cA = cast(MD4CAdapter*) userdata;
		md4cA.enterSpan(type, detail);
		return 0;
	}

	int md4ca_leave_span(MD_SPANTYPE type, void* detail, void* userdata) @system {
		auto md4cA = cast(MD4CAdapter*) userdata;
		md4cA.leaveSpan(type, detail);
		return 0;
	}

	int md4ca_text(MD_TEXTTYPE type, const(MD_CHAR)* text, MD_SIZE size, void* userdata) @system {
		auto md4cA = cast(MD4CAdapter*) userdata;
		md4cA.text(type, text[0 .. size]);
		return 0;
	}
}

private {
	int md_parse_pure(const(MD_CHAR)* text, MD_SIZE size, const(MD_PARSER)* parser, void* userdata) pure {
		auto mdParse = &md_parse;
		auto mdParseFauxPure = cast(int function(const(MD_CHAR)*, MD_SIZE, const(MD_PARSER)*, void*) pure) mdParse;
		return mdParseFauxPure(text, size, parser, userdata);
	}

	Node runParser(hstring data) @trusted pure {
		auto adapter = MD4CAdapter();

		auto parser = MD_PARSER();
		parser.abi_version = 0;
		parser.flags = md4cFlags;
		parser.enter_block = &md4ca_enter_block;
		parser.leave_block = &md4ca_leave_block;
		parser.enter_span = &md4ca_enter_span;
		parser.leave_span = &md4ca_leave_span;
		parser.text = &md4ca_text;
		parser.leave_span = &md4ca_leave_span;
		parser.debug_log = null;
		parser.syntax = null;

		const status = md_parse_pure(data.ptr, data.length.to!MD_SIZE, &parser, &adapter);
		if (status != 0) {
			throw new Exception("Markdown parsing failed.");
		}

		return adapter.root;
	}

	hstring outdentLines(hstring data) pure {
		import std.array : appender;
		import std.string : indexOf, startsWith;

		static bool isSkippable(char c) {
			import std.ascii : isGraphical;

			return ((!c.isGraphical) && (c < '\x80'));
		}

		static hstring skipEmptyLines(hstring data) {
			foreach (idx, c; data) {
				// empty line (whitespace only)?
				if (c == '\n') {
					const idxNext = (idx + 1);
					return skipEmptyLines(data[idxNext .. $]);
				}

				if (!isSkippable(c)) {
					return data;
				}
			}

			return null;
		}

		static size_t determineIndent(hstring data) {
			foreach (idx, c; data) {
				if (!isSkippable(c)) {
					return idx;
				}
			}

			return 0;
		}

		auto result = appender!hstring;

		data = skipEmptyLines(data);
		const idxIndentEnd = determineIndent(data);
		const indent = data[0 .. idxIndentEnd];

		while (data.length > 0) {
			auto idxLF = data.indexOf("\n");
			ptrdiff_t idxEOL;
			if (idxLF < 0) {
				idxEOL = data.length;
			} else {
				idxEOL = idxLF + 1;
			}

			auto line = data[0 .. idxEOL];
			if (line.startsWith(indent)) {
				line = line[indent.length .. $];
			}

			result ~= line;

			data = data[idxEOL .. $];
		}

		return result[];
	}

	Node parseMDImpl(hstring data) @trusted pure {
		data = data.outdentLines();
		return runParser(data);
	}
}

///
Node parseMD(hstring data) @safe pure {
	Node node = parseMDImpl(data);

	if (node is null) {
		return new NullNode();
	}

	return node;
}
