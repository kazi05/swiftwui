import SwiftWUI

/// sitemap.xml generation (spec §10). The protocol caps one file at 50 000
/// URLs / 50 MB; 45 000 leaves headroom. Above it, an index fans out to chunks.
public enum Sitemap {
    public static func documents(paths: [String], siteURL: String, lastmod: String,
                                 maxPerFile: Int = 45_000) -> [(name: String, xml: String)] {
        var origin = siteURL
        while origin.hasSuffix("/") { origin.removeLast() }
        let urls = paths.map { origin + RouteURL._normalize($0) }
        guard urls.count > maxPerFile else {
            return [("sitemap.xml", urlSet(urls, lastmod: lastmod))]
        }
        var out: [(String, String)] = []
        var chunks: [String] = []
        var index = 1
        var start = 0
        while start < urls.count {
            let end = min(start + maxPerFile, urls.count)
            let name = "sitemap-\(index).xml"
            out.append((name, urlSet(Array(urls[start..<end]), lastmod: lastmod)))
            chunks.append(origin + "/" + name)
            start = end
            index += 1
        }
        let idx = """
        <?xml version="1.0" encoding="UTF-8"?>
        <sitemapindex xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
        \(chunks.map { "<sitemap><loc>\(HTMLEscaping.text($0))</loc><lastmod>\(HTMLEscaping.text(lastmod))</lastmod></sitemap>" }.joined(separator: "\n"))
        </sitemapindex>
        """
        return [("sitemap.xml", idx)] + out
    }

    private static func urlSet(_ urls: [String], lastmod: String) -> String {
        """
        <?xml version="1.0" encoding="UTF-8"?>
        <urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
        \(urls.map { "<url><loc>\(HTMLEscaping.text($0))</loc><lastmod>\(HTMLEscaping.text(lastmod))</lastmod></url>" }.joined(separator: "\n"))
        </urlset>
        """
    }
}
