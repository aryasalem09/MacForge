const HOST_NAME = "com.aryasalem.macforge.browserbridge";

async function collectMediaSession(tabId) {
  const [result] = await chrome.scripting.executeScript({
    target: { tabId },
    func: () => {
      const metadata = navigator.mediaSession && navigator.mediaSession.metadata;
      return {
        title: metadata && metadata.title ? metadata.title : document.title,
        artist: metadata && metadata.artist ? metadata.artist : null,
        album: metadata && metadata.album ? metadata.album : null,
        playbackState: "unknown",
        duration: null,
        position: null,
        artworkURL: metadata && metadata.artwork && metadata.artwork[0] ? metadata.artwork[0].src : null,
        sourceURL: location.href,
        browserName: "Chromium Browser",
        tabTitle: document.title
      };
    }
  });

  return result && result.result;
}

chrome.action.onClicked.addListener(async (tab) => {
  if (!tab || !tab.id) return;
  const message = await collectMediaSession(tab.id);
  if (!message) return;
  chrome.runtime.sendNativeMessage(HOST_NAME, message);
});
