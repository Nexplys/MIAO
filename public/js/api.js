"use strict";

(function exposeMiaoApi(globalObject) {
  function encodeBase64Utf8(value) {
    const bytes = new TextEncoder().encode(value);
    let binary = "";

    for (const byte of bytes) {
      binary += String.fromCharCode(byte);
    }

    return btoa(binary);
  }

  async function parseResponse(response) {
    const result = await response.json().catch(() => ({}));
    if (!response.ok || result.ok === false) {
      throw new Error(result.error || "M.I.A.O. n’a pas pu traiter la demande.");
    }
    return result;
  }

  async function getJson(url) {
    const separator = url.includes("?") ? "&" : "?";
    const response = await fetch(`${url}${separator}t=${Date.now()}`, {
      cache: "no-store"
    });
    return parseResponse(response);
  }

  async function postJson(url, data = {}) {
    const response = await fetch(url, {
      method: "POST",
      headers: {
        "Content-Type": "text/plain; charset=us-ascii"
      },
      body: encodeBase64Utf8(JSON.stringify(data)),
      cache: "no-store"
    });
    return parseResponse(response);
  }

  globalObject.MiaoApi = Object.freeze({
    getJson,
    postJson
  });
})(window);
