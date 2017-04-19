(function() {
    require(['/js/eventbus.js', '/js/events.js'], function(eventBus, events) {
        //$('.time-duration').each(function() {
            //var $self = $(this);
            //$self.text(moment.duration($self.text() * 1000).humanize(), 'seconds');
        //});
        //$('.date-relative').each(function() {
            //var $self = $(this);
            //$self.text(moment($self.text()).fromNow());
        //});

        eventBus.subscribe('*', function(ev, data) {
            console.log(data);

            if (data.output) {
                $('.console').append(data.output);
            }
        });

        //events.connect('/events', function(data) {
            //eventBus.publish(data.type, data.data);
        //});

        $('.console').each(function(index, el) {
            var build = $(el).data('build');

            $(el).height($(window).height() - 150);

            var es = events.connect('/tail', function(ev) {
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
    });
})();
