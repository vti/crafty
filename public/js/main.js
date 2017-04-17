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

        events.connect('/events', function(data) {
            eventBus.publish(data.type, data.data);
        });
    });
})();
