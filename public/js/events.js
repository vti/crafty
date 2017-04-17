define(["/js/lib/EventSource.js"], function() {
    function openEvents(url, handler, timeout) {
        var es = new EventSource(url, { withCredentials: true });
        var listener = function (ev) {
            if (ev.type === "message") {
                if (ev.data) {
                    handler(jQuery.parseJSON(ev.data));
                }
            }
            else if (ev.type === "error") {
                es.close();
                setTimeout(function() {
                    if (timeout < 300000) {
                        timeout = timeout * 2;
                    }

                    openEvents(url, handler, timeout);
                }, timeout);
            }
            else if (ev.type === "open") {
                timeout = 1000;
            }
        };
        es.addEventListener("open", listener);
        es.addEventListener("message", listener);
        es.addEventListener("error", listener);
    }

    return {
        connect: function(url, handler) {
            openEvents(url, handler, 1000);
        }
    }
});
