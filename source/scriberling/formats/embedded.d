/++
	Embedded App Nodes
 +/
module scriberling.formats.embedded;

import scriberling.data.dom;
import scriberling.formats.embedding;
import scriberling.types;

///
final class EmbeddedAppNode : Node {

	public {
		hstring app;
		hstring data;
		Location location;
	}

	///
	override void analyze(const SiteConfig) pure {
		// TODO
		analyzeEmbeddedAppNode(app, data);
		return;
	}

	override void compile(Sink sink) {
		// TODO: Implement
		sink.put("<div>Error: Feature not implemented.</div>");
	}
}
