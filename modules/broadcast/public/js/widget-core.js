"use strict";

(function exposeMiaoWidgetCore(globalObject) {
  function normalizeText(value) {
    return String(value ?? "")
      .replace(/\r\n/g, "\n")
      .replace(/\r/g, "\n")
      .trim();
  }

  function hexToRgba(hex, opacity) {
    const safeHex = /^#[0-9a-f]{6}$/i.test(hex) ? hex.slice(1) : "000000";
    const red = Number.parseInt(safeHex.slice(0, 2), 16);
    const green = Number.parseInt(safeHex.slice(2, 4), 16);
    const blue = Number.parseInt(safeHex.slice(4, 6), 16);
    return `rgba(${red}, ${green}, ${blue}, ${opacity})`;
  }

  function textLength(value) {
    return Array.from(value).length;
  }

  function wrapWords(text, maximumLength) {
    const wrappedLines = [];

    for (const paragraph of normalizeText(text).split("\n")) {
      const words = paragraph.trim().split(/\s+/).filter(Boolean);
      let currentLine = "";

      for (const originalWord of words) {
        let word = originalWord;
        const candidate = currentLine ? `${currentLine} ${word}` : word;

        if (textLength(candidate) <= maximumLength) {
          currentLine = candidate;
          continue;
        }

        if (currentLine) {
          wrappedLines.push(currentLine);
          currentLine = "";
        }

        while (textLength(word) > maximumLength) {
          const characters = Array.from(word);
          wrappedLines.push(characters.slice(0, maximumLength).join(""));
          word = characters.slice(maximumLength).join("");
        }

        currentLine = word;
      }

      if (currentLine) {
        wrappedLines.push(currentLine);
      }
    }

    return wrappedLines.join("\n");
  }

  function wrapSongTitle(song, maximumLength) {
    const normalizedSong = normalizeText(song);
    if (textLength(normalizedSong) <= maximumLength) {
      return normalizedSong;
    }

    const separatorIndex = normalizedSong.indexOf(" - ");
    if (separatorIndex <= 0) {
      return wrapWords(normalizedSong, maximumLength);
    }

    const artist = normalizedSong.slice(0, separatorIndex).trim();
    const title = normalizedSong.slice(separatorIndex + 3).trim();
    const artistLines = wrapWords(artist, Math.max(4, maximumLength - 2)).split("\n");
    const lastArtistLine = artistLines.length - 1;

    if (textLength(artistLines[lastArtistLine]) + 2 <= maximumLength) {
      artistLines[lastArtistLine] += " -";
    } else {
      artistLines.push("-");
    }

    return [...artistLines, wrapWords(title, maximumLength)].join("\n");
  }

  function buildRadioText(state) {
    const settings = state.settings;
    const title = wrapSongTitle(
      state.song || settings.radioEmptyText,
      settings.songLineLength
    );
    return [settings.radioHeader, settings.radioLabel, title].join("\n");
  }

  function getAvailablePages(state) {
    const settings = state.settings;
    const showRadio = settings.radioEnabled &&
      !(settings.radioAutoHideWhenEmpty && !state.song);
    const showMission = settings.missionEnabled && Boolean(state.mission);
    const pages = [];

    if (showRadio) {
      pages.push({
        id: "radio",
        text: buildRadioText(state),
        duration: settings.radioHoldSeconds * 1000
      });
    }
    if (showMission) {
      pages.push({
        id: "mission",
        text: state.mission,
        duration: settings.missionHoldSeconds * 1000
      });
    }

    return pages;
  }

  globalObject.MiaoWidgetCore = Object.freeze({
    normalizeText,
    hexToRgba,
    wrapWords,
    wrapSongTitle,
    getAvailablePages
  });
})(window);
