/* Service worker do Controle de Produção de Leite.
   Serve para duas coisas: deixar o site instalável como aplicativo no celular
   e fazer ele abrir sem sinal, com a última versão que o aparelho baixou.

   Estratégia, de propósito diferente por tipo de arquivo:
   - a página (index.html): REDE PRIMEIRO. Assim uma correção publicada chega
     no próximo acesso com internet. Sem sinal, cai para a cópia guardada.
   - ícones e manifest: CACHE PRIMEIRO. Não mudam quase nunca.
   Os dados de produção NÃO passam por aqui: eles moram no armazenamento do
   aparelho e vão para o Supabase pela própria página. */

var VERSAO = "leite-v1";
var ESSENCIAIS = [
  "./",
  "./index.html",
  "./manifest.webmanifest",
  "./icones/icone-192.png",
  "./icones/icone-512.png",
  "./icones/icone-512-mascara.png",
  "./icones/icone-apple-180.png"
];

self.addEventListener("install", function (evento) {
  evento.waitUntil(
    caches.open(VERSAO).then(function (cache) {
      // addAll falha inteiro se um arquivo faltar; guardamos um por um
      return Promise.all(ESSENCIAIS.map(function (url) {
        return cache.add(new Request(url, { cache: "reload" })).catch(function () {});
      }));
    }).then(function () { return self.skipWaiting(); })
  );
});

self.addEventListener("activate", function (evento) {
  evento.waitUntil(
    caches.keys().then(function (nomes) {
      return Promise.all(nomes.map(function (n) {
        return n === VERSAO ? null : caches.delete(n);
      }));
    }).then(function () { return self.clients.claim(); })
  );
});

self.addEventListener("fetch", function (evento) {
  var req = evento.request;
  if (req.method !== "GET") return;

  var url = new URL(req.url);
  if (url.origin !== self.location.origin) return;   // Supabase e afins passam direto

  var ehPagina = req.mode === "navigate" ||
                 (req.headers.get("accept") || "").indexOf("text/html") >= 0;

  if (ehPagina) {
    evento.respondWith(
      fetch(req).then(function (resp) {
        var copia = resp.clone();
        caches.open(VERSAO).then(function (c) { c.put("./index.html", copia); });
        return resp;
      }).catch(function () {
        return caches.match("./index.html").then(function (r) {
          return r || new Response(
            "<meta charset=utf-8><p style=\"font:16px system-ui;padding:24px\">" +
            "Sem internet e sem cópia guardada ainda. Abra uma vez com sinal.",
            { headers: { "Content-Type": "text/html; charset=utf-8" } }
          );
        });
      })
    );
    return;
  }

  evento.respondWith(
    caches.match(req).then(function (guardado) {
      return guardado || fetch(req).then(function (resp) {
        if (resp && resp.ok) {
          var copia = resp.clone();
          caches.open(VERSAO).then(function (c) { c.put(req, copia); });
        }
        return resp;
      });
    })
  );
});
