(function() {
    require(['/js/eventbus.js', '/js/events.js', '/js/lib/moment.min.js'], function(eventBus, events, moment) {
        $('.time-duration').each(function() {
            var $self = $(this);
            $self.text(moment.duration($self.text() * 1000).humanize(), 'seconds');
        });
        $('.date-relative').each(function() {
            var $self = $(this);
            $self.text(moment($self.text()).fromNow());
        });

        eventBus.subscribe('*', function(ev, data) {
            console.log(ev);
            console.log(data);

            $('[data-event="' + ev + '"]' + (data.uuid ? '[data-uuid="' + data.uuid + '"]' : '')).each(function(index, el) {
                var key = $(el).data('key');
                var method = $(el).data('method');

                if (key) {
                    var value = data[key];

                    if (method == 'toggle') {
                        $(el).removeClass('hidden');
                        if (value) {
                            $(el).css('visibility', 'visible');
                        } else {
                            $(el).css('visibility', 'hidden');
                        }
                    } else if (method == 'text') {
                        $(el).text(data[key]);
                    } else if (method == 'replace_class') {
                        var prefix = $(el).data('prefix');
                        $(el).attr('class', function(index, className) {
                            var re = new RegExp('(\\s|^)' + prefix + '[^\\s]+');

                            return className.replace(re, ' ' + prefix + value);
                        });
                    }
                }
                else if (method == 'prepend') {
                    $(el).prepend('<tr><td>hi there</td></tr>')
                }
            });
        });

        events.connect('/events', function(data) {
            eventBus.publish(data.type, data.data);
        });

        $('.console').each(function(index, el) {
            var build = $(el).data('build');

            $(el).height($(window).height() - 150);

            var es = events.connect('/tail/' + build, function(ev) {
                if (ev.type == 'output') {
                    var data = ev.data.replace(/\\n/g, "\n");
                    $(el).append(data);
                }
                else {
                    es.close();
                }

                $(el).scrollTop($(el)[0].scrollHeight);
            });
        });

        $('form.ajax').submit(function() {
            var self = this;
            var action = $(this).attr('action');
            var method = $(this).attr('method');

            $.ajax({
                method: method,
                url: action,
                success: function() {},
                error: function() {}
            });

            return false;
        });
    });
})();
