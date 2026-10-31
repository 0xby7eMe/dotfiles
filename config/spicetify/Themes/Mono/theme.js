/*
 * Mono — theme.js
 *
 * 1. Live wallpaper: xpui/rice-wall.jpg is a symlink to ~/.config/background,
 *    which quickshell overwrites (cp -f) when the wallpaper changes. CEF never
 *    re-reads a url() it already loaded, so poll the file, and when its bytes
 *    change hand the new image to the CSS as a blob URL (--mono-wall).
 *
 * 2. Cover backdrop: album / playlist headers get their cover art, blurred,
 *    as background (--mono-cover on .main-entityHeader-container).
 */
(function mono() {
    if (!document.body) {
        document.addEventListener("DOMContentLoaded", mono, { once: true });
        return;
    }

    /* ---------- wallpaper watcher ---------- */
    const WALL = "/rice-wall.jpg";
    const POLL_MS = 2000;
    const SETTLE_MS = 300; // cp -f writes in place; wait out partial files

    let wallSig = null;
    let wallUrl = null;
    let checking = false;

    async function readWall() {
        const res = await fetch(`${WALL}?t=${Date.now()}`, { cache: "no-store" });
        if (!res.ok) throw new Error(`rice-wall.jpg: HTTP ${res.status}`);
        const blob = await res.blob();
        const hash = await crypto.subtle.digest("SHA-1", await blob.arrayBuffer());
        const sig = blob.size + ":" + Array.from(new Uint8Array(hash), b => b.toString(16).padStart(2, "0")).join("");
        return { blob, sig };
    }

    async function checkWall() {
        if (checking || document.hidden) return;
        checking = true;
        try {
            const first = await readWall();
            if (first.sig === wallSig || first.blob.size === 0) return;

            await new Promise(r => setTimeout(r, SETTLE_MS));
            const { blob, sig } = await readWall();
            if (sig !== first.sig) return; // still being written, next tick

            const url = URL.createObjectURL(blob);
            const img = new Image();
            img.src = url;
            try {
                await img.decode();
            } catch {
                URL.revokeObjectURL(url);
                return;
            }

            document.documentElement.style.setProperty("--mono-wall", `url("${url}")`);
            if (wallUrl) {
                const old = wallUrl;
                setTimeout(() => URL.revokeObjectURL(old), 2000); // after the crossfade
            }
            wallUrl = url;
            wallSig = sig;
        } catch (e) {
            console.warn("[mono] wallpaper check failed:", e);
        } finally {
            checking = false;
        }
    }

    checkWall();
    setInterval(checkWall, POLL_MS);
    window.addEventListener("focus", checkWall);
    document.addEventListener("visibilitychange", checkWall);

    /* ---------- cover backdrop for album / playlist headers ---------- */
    const COVER_IMG = [
        ".main-entityHeader-imageContainerNew img",
        ".main-entityHeader-imageContainer img",
        ".main-entityHeader-image img",
        "img.main-entityHeader-image",
        '[data-testid="entity-image"] img',
        'img[data-testid="entity-image"]',
    ].join(",");

    function isCoverPage() {
        const p = (window.Spicetify?.Platform?.History?.location?.pathname) || location.pathname;
        return /^\/(album|playlist|collection\/tracks)\b/.test(p);
    }

    function updateCovers() {
        const cover = isCoverPage();
        for (const header of document.querySelectorAll(".main-entityHeader-container")) {
            const img = cover && header.querySelector(COVER_IMG);
            const src = img && (img.currentSrc || img.src);
            if (src && !src.startsWith("data:")) {
                if (header.dataset.monoCover !== src) {
                    header.dataset.monoCover = src;
                    header.style.setProperty("--mono-cover", `url("${src.replace(/"/g, "%22")}")`);
                    // restart the fade-in when the cover changes in place
                    header.classList.remove("mono-cover");
                    void header.offsetWidth;
                }
                header.classList.add("mono-cover");
            } else if (header.classList.contains("mono-cover")) {
                header.classList.remove("mono-cover");
                header.style.removeProperty("--mono-cover");
                delete header.dataset.monoCover;
            }
        }
    }

    let queued = false;
    new MutationObserver(() => {
        if (queued) return;
        queued = true;
        requestAnimationFrame(() => {
            queued = false;
            updateCovers();
        });
    }).observe(document.body, {
        childList: true,
        subtree: true,
        attributes: true,
        attributeFilter: ["src", "srcset"],
    });
    updateCovers();
})();
