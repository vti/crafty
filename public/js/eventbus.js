define([], function() {
    if (!window.EventBus) {
        window.EventBus = {
            listeners: {},
            publish: function(ev, data) {
                var i;

                if (this.listeners[ev]) {
                    for (i = 0; i < this.listeners[ev].length; i++) {
                        try {
                            this.listeners[ev][i](ev, data);
                        } catch (e) {
                        }
                    }
                }

                if (this.listeners['*']) {
                    for (i = 0; i < this.listeners['*'].length; i++) {
                        this.listeners['*'][i](ev, data);
                    }
                }
            },
            subscribe: function(ev, callback) {
                if (!this.listeners[ev]) {
                    this.listeners[ev] = [];
                }

                this.listeners[ev].push(callback);
            }
        };
    }

    return window.EventBus;
});
