/++
	Embedded App processing
 +/
module scriberling.formats.embedding;

import scriberling.data.dom;
import scriberling.types;

@safe pure:

Node analyzeEmbeddedAppNode(hstring app, hstring data, const SiteConfig siteConfig) {
	auto node = retrieveNode(app, data);
	assert(node !is null, "No DOM node returned for block processed by app `" ~ app ~ "`.");

	node.analyze(siteConfig);

	return node;
}

Node retrieveNode(hstring app, hstring data) {
	static string makeExceptionMessage(hstring app) {
		return "No app available to process embedded block of type `" ~ app ~ "`.";
	}

	switch (app) {

	case "md":
	case "markdown":
		return analyzeMD(data);

	case "html":
	case "raw":
	case "script":
	case "style":
		return analyzeHTML(data);

	case "scriberling":
		return analyzeSDF(data);

	default:
		throw new Exception(makeExceptionMessage(app));
	}
}

Node analyzeMD(hstring data) {
	import scriberling.formats.md.parser;

	return parseMD(data);
}

Node analyzeHTML(hstring data) {
	import scriberling.formats.html.parser;

	return parseHTML(data);
}

Node analyzeSDF(hstring data) {
	import scriberling.formats.sdf.parser;

	return parseSDF(data);
}
