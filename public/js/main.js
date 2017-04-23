(function() {
    require([
        '/js/eventbus.js',
        '/js/events.js',
        '/js/lib/moment.min.js',
        '/js/lib/mustache.min.js'
    ], function(eventBus, events, moment, mustache) {
        function formatTimeDuration(text) {
            if (text <= 0)
                return 'n/a';
            return moment.duration(text * 1000).humanize();
        }

        function formatDateRelative(text) {
            if (!text)
                return 'n/a';
            return moment(text).fromNow();
        }

        function updateTimeFormatting() {
            $('.time-duration:visible').each(function() {
                var value = $(this).attr('title');
                $(this).text(formatTimeDuration(value));
            });

            $('.date-relative:visible').each(function() {
                var value = $(this).attr('title');
                $(this).text(formatDateRelative(value));
            });
        }

        updateTimeFormatting();

        setInterval(function() {
            updateTimeFormatting()
        }, 60 * 1000);

        eventBus.subscribe('*', function(ev, data) {
            var selector = '[data-event="' + ev + '"]' +
                (!data.is_new && data.uuid ? '[data-uuid="' + data.uuid + '"]' : '');

            $(selector).each(function(index, el) {
                var key = $(el).data('key');
                var method = $(el).data('method');

                if (key) {
                    var value = data[key];

                    if (method == 'toggle') {
                        $(el).removeClass('hidden');
                        if (value) {
                            $(el).removeClass('hidden');
                        } else {
                            $(el).addClass('hidden');
                        }
                    } else if (method == 'text') {
                        var value = data[key];
                        var attr = $(el).data('attr');

                        if (attr) {
                            $(el).attr(attr, value);
                        }

                        if ($(el).hasClass('date-relative')) {
                            value = formatDateRelative(value);
                        }
                        if ($(el).hasClass('time-duration')) {
                            value = formatTimeDuration(value);
                        }

                        $(el).text(value);
                    } else if (method == 'replace_class') {
                        var prefix = $(el).data('prefix');
                        $(el).attr('class', function(index, className) {
                            var re = new RegExp('(\\s|^)' + prefix + '[^\\s]+');

                            return className.replace(re, ' ' + prefix + value);
                        });
                    }
                } else if (method == 'prepend') {
                    var templateName = $(el).data('template');

                    var template = $(templateName).clone();

                    var rendered = mustache.render(template.html(), data);

                    $(el).prepend(rendered);
                }
            });
        });

        events.connect('/events', function(data) {
            eventBus.publish(data.type, data.data);
        });

        $('.console').each(function(index, el) {
            var build = $(el).data('build');

            $(el).height($(window).height() - 250);

            var es = events.connect('/tail/' + build, function(ev) {
                if (ev.type == 'output') {
                    var data = ev.data.replace(/\\n/g, "\n");
                    $(el).append(data);
                } else {
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
