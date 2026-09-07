import express from "express";
import cors from "cors";
import axios from "axios";
import * as cheerio from "cheerio";
import { httpServerHandler } from "cloudflare:node";

const app = express();

app.use(cors());
app.use(express.json());

const BASE_URL = "https://moviesdatamil.co";

const DEFAULT_HEADERS = {
    "User-Agent":
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
    "Accept":
        "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8",
    "Accept-Language": "en-US,en;q=0.9"
};

/**
 * Extracts total pages dynamically from cheerio parsed HTML
 */
function extractTotalPages($) {
    // 1. Check .pages-info (e.g. "Showing Page 1 of 17")
    const pagesInfoText = $(".pages-info").text();
    const match1 = pagesInfoText.match(/Showing Page \d+ of (\d+)/i);
    if (match1) {
        return parseInt(match1[1], 10);
    }

    // 2. Check full body text for "Page X of Y"
    const bodyText = $("body").text();
    const match2 = bodyText.match(/Page \d+ of (\d+)/i);
    if (match2) {
        return parseInt(match2[1], 10);
    }

    // 3. Scan pagination links for highest ?page= number
    let maxPage = 1;
    $('a[href*="page="]').each((_, el) => {
        const href = $(el).attr("href") || "";
        const m = href.match(/page=(\d+)/);
        if (m) {
            const pageNum = parseInt(m[1], 10);
            if (pageNum > maxPage) maxPage = pageNum;
        }
    });

    return maxPage;
}

/**
 * Scrapes movies for a given year dynamically detecting total pages
 */
async function scrapeMoviesByYear(year) {
    const cleanYear = String(year).trim();
    if (!/^\d{4}$/.test(cleanYear)) {
        throw new Error("Invalid year format. Must be a 4-digit year (e.g. 2026).");
    }

    const page1Url = `${BASE_URL}/tamil-${cleanYear}-movies/`;
    console.log(`[Scraper] Fetching page 1 for year ${cleanYear}: ${page1Url}`);

    const response = await axios.get(page1Url, {
        timeout: 15000,
        headers: DEFAULT_HEADERS
    });

    const $1 = cheerio.load(response.data);
    const pageTitle = $1("title").text();

    // Check if page actually exists for this year or fell back to home page
    if (!pageTitle.toLowerCase().includes(cleanYear) && !pageTitle.toLowerCase().includes("tamil")) {
        return {
            success: false,
            year: cleanYear,
            totalPages: 0,
            total: 0,
            movies: [],
            message: `No movie catalogue found for year ${cleanYear}`
        };
    }

    const totalPages = extractTotalPages($1);
    console.log(`[Scraper] Year ${cleanYear}: detected ${totalPages} total pages from HTML`);

    const allMovies = [];

    // Parse movies from Page 1
    $1(".f").each((_, element) => {
        const link = $1(element).find("a").first();
        const title = link.text().trim();
        const slug = link.attr("href");

        // Filter out navigation category redirects like "(Tamil 2026 Movies)"
        if (title && slug && !slug.includes(`tamil-${cleanYear}-movies`)) {
            allMovies.push({ title, slug });
        }
    });

    // If there are more pages, fetch remaining pages concurrently in parallel
    if (totalPages > 1) {
        const pagePromises = [];
        for (let page = 2; page <= totalPages; page++) {
            const pageUrl = `${BASE_URL}/tamil-${cleanYear}-movies/?page=${page}`;
            pagePromises.push(
                axios.get(pageUrl, {
                    timeout: 15000,
                    headers: DEFAULT_HEADERS
                }).then(res => {
                    const $ = cheerio.load(res.data);
                    const pageMovies = [];
                    $(".f").each((_, element) => {
                        const link = $(element).find("a").first();
                        const title = link.text().trim();
                        const slug = link.attr("href");
                        if (title && slug && !slug.includes(`tamil-${cleanYear}-movies`)) {
                            pageMovies.push({ title, slug });
                        }
                    });
                    return { page, movies: pageMovies };
                }).catch(err => {
                    console.error(`[Scraper] Error fetching page ${page} for year ${cleanYear}:`, err.message);
                    return { page, movies: [] };
                })
            );
        }

        const pageResults = await Promise.all(pagePromises);
        pageResults.sort((a, b) => a.page - b.page);
        for (const res of pageResults) {
            allMovies.push(...res.movies);
        }
    }

    return {
        success: true,
        year: cleanYear,
        totalPages,
        total: allMovies.length,
        movies: allMovies
    };
}

// Route to fetch movies by year param
app.get("/api/movies/year/:year", async (req, res) => {
    try {
        const year = req.params.year;
        const result = await scrapeMoviesByYear(year);
        res.json(result);
    } catch (error) {
        console.error("Scraping error:", error.message);
        res.status(500).json({
            success: false,
            message: error.message || "Unable to fetch movie catalogue",
            error: error.message
        });
    }
});

// Route to fetch movies via query parameter (?year=2026)
app.get("/api/movies", async (req, res) => {
    try {
        const year = req.query.year || "2026";
        const result = await scrapeMoviesByYear(year);
        res.json(result);
    } catch (error) {
        console.error("Scraping error:", error.message);
        res.status(500).json({
            success: false,
            message: error.message || "Unable to fetch movie catalogue",
            error: error.message
        });
    }
});

/**
 * Checks if a link is a terminal direct download link
 */
function isDirectDownloadLink(href) {
    if (!href) return false;
    const h = href.toLowerCase();
    if (
        h.includes("onestream.today") ||
        h.includes("downloadpage.xyz") ||
        h.includes("moviespage.xyz")
    ) {
        return false;
    }
    return (
        h.includes("fastbytes.xyz") ||
        h.includes("uptomkv.ch") ||
        h.includes("southmango.xyz") ||
        h.includes("northpanda.xyz") ||
        h.includes("eastpotato.xyz") ||
        h.includes("download.php?dl=") ||
        h.endsWith(".mp4") ||
        h.endsWith(".mkv") ||
        h.endsWith(".avi")
    );
}

/**
 * Checks if a link is navigation clutter to ignore
 */
function isIgnoredLink(href, text) {
    if (!href) return true;
    const h = href.toLowerCase();
    const t = (text || "").toLowerCase();
    if (h.startsWith("#") || h.startsWith("javascript:")) return true;
    if (
        h.includes("facebook") ||
        h.includes("twitter") ||
        h.includes("whatsapp") ||
        h.includes("telegram")
    )
        return true;
    if (
        h.includes("/tamil-movies/") ||
        h === "/" ||
        h.includes("disclaimer") ||
        h.includes("dmca") ||
        h.includes("contact")
    )
        return true;
    if (
        t === "home" ||
        t === "disclaimer" ||
        t === "contact us" ||
        t === "dmca" ||
        t === "moviesda home"
    )
        return true;
    if (h.includes("tamil-") && h.includes("-movies/")) return true;
    if (h.includes("onestream.today") || t.includes("watch online") || t.includes("stream")) return true;
    return false;
}

/**
 * Parses extra metadata from direct download URLs (e.g. FastBytes/Uptomkv base64 path)
 */
function parseDownloadItemDetails(item) {
    let filename = item.title;
    let quality = "";
    const url = item.downloadUrl;
    const isFastbytes = url.includes("fastbytes.xyz") || url.includes("uptomkv.ch");

    if (url.includes("dl=")) {
        try {
            const urlObj = new URL(url);
            const dl = urlObj.searchParams.get("dl");
            if (dl) {
                const decoded = Buffer.from(dl, "base64").toString("utf8");
                const params = new URLSearchParams(decoded);
                const path = params.get("path");
                if (path) {
                    const parts = path.split("/");
                    filename = parts[parts.length - 1];
                    if (parts.length > 1) {
                        quality = parts[parts.length - 2];
                    }
                }
            }
        } catch (_) { }
    } else if (url.endsWith(".mp4") || url.includes(".mp4")) {
        try {
            const urlObj = new URL(url);
            const pathParts = urlObj.pathname.split("/");
            const name = pathParts[pathParts.length - 1];
            if (name) {
                filename = decodeURIComponent(name).replace(/_/g, " ");
            }
        } catch (_) { }
    }

    return {
        ...item,
        filename: filename || item.title,
        quality: quality || (item.title !== filename ? item.title : ""),
        isFastbytes,
        format: "MP4"
    };
}

/**
 * Recursively resolves a movie slug/URL to its direct download links
 */
async function resolveMovieDownloads(initialPath, maxDepth = 6) {
    const visited = new Set();
    const rawDownloads = [];

    async function crawl(currentUrl, depth, pathHistory = []) {
        const fullUrl = currentUrl.startsWith("http")
            ? currentUrl
            : `${BASE_URL}${currentUrl.startsWith("/") ? "" : "/"}${currentUrl}`;

        if (visited.has(fullUrl) || depth > maxDepth) return;
        visited.add(fullUrl);

        if (isDirectDownloadLink(fullUrl)) {
            rawDownloads.push({
                title: pathHistory[pathHistory.length - 1] || "Download Link",
                downloadUrl: fullUrl,
                sourcePage:
                    pathHistory.length > 1
                        ? pathHistory[pathHistory.length - 2]
                        : fullUrl
            });
            return;
        }

        try {
            const res = await axios.get(fullUrl, {
                headers: DEFAULT_HEADERS,
                timeout: 12000,
                maxRedirects: 5
            });

            const $ = cheerio.load(res.data);
            const pageTitle = $("title").text().trim();
            const nextLinks = [];

            // Follow navigation and download server links
            $("a").each((_, el) => {
                const href = $(el).attr("href");
                const text = $(el).text().trim();
                if (!href || isIgnoredLink(href, text)) return;

                const nextFullUrl = href.startsWith("http")
                    ? href
                    : `${BASE_URL}${href.startsWith("/") ? "" : "/"}${href}`;

                if (isDirectDownloadLink(nextFullUrl)) {
                    rawDownloads.push({
                        title: text || pageTitle,
                        downloadUrl: nextFullUrl,
                        sourcePage: fullUrl
                    });
                } else if (!visited.has(nextFullUrl)) {
                    const parentClass = $(el).parent().attr("class") || "";
                    const aClass = $(el).attr("class") || "";
                    const isContentLink =
                        aClass.includes("coral") ||
                        parentClass.includes("dlink") ||
                        parentClass.includes("f") ||
                        parentClass.includes("download") ||
                        $(el).closest(".f").length > 0 ||
                        $(el).closest(".download").length > 0 ||
                        nextFullUrl.includes("moviespage.xyz") ||
                        nextFullUrl.includes("downloadpage.xyz") ||
                        nextFullUrl.includes("/download/");

                    if (isContentLink || depth < 3) {
                        nextLinks.push({ url: nextFullUrl, text: text || pageTitle });
                    }
                }
            });

            if (nextLinks.length > 0) {
                await Promise.all(
                    nextLinks.map(nl =>
                        crawl(nl.url, depth + 1, [...pathHistory, nl.text])
                    )
                );
            }
        } catch (err) {
            console.error(`[Crawl Error at ${fullUrl}]:`, err.message);
        }
    }

    await crawl(initialPath, 0, []);

    // Deduplicate and enrich items
    const uniqueDownloads = [];
    const seenUrls = new Set();
    for (const item of rawDownloads) {
        if (!item.downloadUrl || item.downloadUrl.includes("onestream.today") || item.downloadUrl.includes("downloadpage.xyz")) {
            continue;
        }
        if (!seenUrls.has(item.downloadUrl)) {
            seenUrls.add(item.downloadUrl);
            uniqueDownloads.push(parseDownloadItemDetails(item));
        }
    }

    return uniqueDownloads;
}

// Endpoint to resolve deep direct download links for a specific movie slug
app.get("/api/movies/download-links", async (req, res) => {
    try {
        const slug = req.query.slug || req.query.url;
        if (!slug) {
            return res.status(400).json({
                success: false,
                message: "Missing 'slug' or 'url' query parameter."
            });
        }

        console.log(`[Deep Resolver] Resolving download links for: ${slug}`);
        const downloads = await resolveMovieDownloads(slug);

        res.json({
            success: true,
            slug,
            total: downloads.length,
            downloads
        });
    } catch (error) {
        console.error("Deep download resolution error:", error.message);
        res.status(500).json({
            success: false,
            message: "Unable to resolve download links for movie",
            error: error.message
        });
    }
});

app.post("/api/movies/download-links", async (req, res) => {
    try {
        const slug = req.body.slug || req.body.url;
        if (!slug) {
            return res.status(400).json({
                success: false,
                message: "Missing 'slug' in request body."
            });
        }

        console.log(`[Deep Resolver] Resolving download links for: ${slug}`);
        const downloads = await resolveMovieDownloads(slug);

        res.json({
            success: true,
            slug,
            total: downloads.length,
            downloads
        });
    } catch (error) {
        console.error("Deep download resolution error:", error.message);
        res.status(500).json({
            success: false,
            message: "Unable to resolve download links for movie",
            error: error.message
        });
    }
});

// Backwards-compatible route for 2022
app.get("/api/movies/tamil-2022", async (req, res) => {
    try {
        const result = await scrapeMoviesByYear("2022");
        res.json(result);
    } catch (error) {
        console.error("Scraping error:", error.message);
        res.status(500).json({
            success: false,
            message: "Unable to fetch movie catalogue",
            error: error.message
        });
    }
});

app.listen(3000);

export default httpServerHandler({
    port: 3000
});

