define(["/js/lib/EventSource.js"], function() {
    function openEvents(url, handler, timeout) {
        var es = new EventSource(url, { withCredentials: true });
        var listener = function (ev) {
            if (ev.type === "message") {
                if (ev.data) {
                    var data = jQuery.parseJSON(ev.data);
                    handler(data[0], data[1]);
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

        return es;
    }

    return {
        connect: function(url, handler) {
            return openEvents(url, handler, 1000);
        }
    }
});
