
$(document).ready(function() {
    $('select').formSelect();
    /* restore UI from query */
    var urlParams = window.location.search;
    urlParams.substr(1).split("&").forEach(function (param) {
        ps = param.split("=");
        if (ps[0] == "q") {
            var query = decodeURIComponent(ps[1]);
            queryObj = adjustControls(query);
        } else if (ps[0] == "page") {
            page = ps[1];
        }
    });

    /* bind search button */
    $('#searchButton').on('click', reloadQuery);
    $('#suspicion').on('change', suspicionChanged);
    $('#accordingTo').on('change', accordingToChanged);

});

re_query = /Query (SuspicionIncomplete|SuspicionUnsound) (Majority|\(AnyOf (.*)\)|\(AllOf (.*)\))/;


function adjustControls(s) {
    if (s == "Everything") {
        setSuspicion("Everything");
    } else {
        var m = s.match(re_query);
        console.log(m);
        if (m) {
            console.log(m[1]);
            var suspicion = m[1];
            setSuspicion(suspicion);
            var mode = m[2];

            if (mode.startsWith("(AnyOf") || mode.startsWith("(AllOf")) {
                var vl = m[3];
                var verifiers = vl.substr(1, vl.length -2).split(",").map(x => x.substr(1, x.length-2));
                setVerifiers(verifiers);
            } else if (mode == "Majority") {
                setMode("Majority");
            }

        } else {
            console.log("could not parse query");
        }
    }
}

function setSuspicion(s) {
    console.log("setting suspicion to " + s);
    $('#suspicion > option').prop('selected', false);
    $('#suspicion option[value="' + s + '"]').prop('selected', true);
    /* re-init */
    $('#suspicion').formSelect();
    suspicionChanged();
}

function setMode(s) {
    console.log("setting mode to " + s);
    if (s == 'Majority') {
        $('#accordingTo option').prop('selected', false);
        $('#accordingTo option[value="' + s + '"]').prop('selected', true);
        $('#accordingTo').formSelect();
        $('#verifier-row').hide();

    }
}

function setVerifiers(vs) {
    console.log("setVerifiers");
    console.log(vs);

    $('#verifiers option').each(function(i, elem){
        var v = $(elem).val();
        if ($.inArray(v, vs) != -1) {
            $(elem).prop('selected', true);
        } else {
            $(elem).prop('selected', false);
        }
    });
    $('#verifiers').formSelect();
}

function reloadQuery() {
    var suspicion = $('#suspicion').val();
    var accordingTo = $('#accordingTo').val();
    var q = "";

    if (suspicion == "Everything") {
        q = "Everything";
    } else {
        if (accordingTo == 'Majority') {
            q = "Query " + suspicion + " Majority";
        } else {
            /* get instance */
            var verifiers = $('#verifiers').val();
            console.log(verifiers);
            var verifiersL = verifiers.map(function(v) {
                return '"' + v + '"';
            }).join(',');
            console.log(verifiersL);
            q = "Query " + suspicion + " (" + accordingTo + " [" + verifiersL + "])";
        }
    }

    window.location = "?q=" + encodeURIComponent(q);
}

function suspicionChanged() {
    var x = $('#suspicion').val();
    if (x == 'Everything') {
        console.log("everything -> hide");
        $('#accordingToBox').hide();
        $('#verifier-row').hide();
    } else {
        $('#accordingToBox').show();
        $('#accordingTo').trigger("change");
    }
}

function accordingToChanged() {
    var x = $('#accordingTo').val();
    if (x == 'Majority') {
        $('#verifier-row').hide();
    } else {
        $('#verifier-row').show();
    }
}
function gotoPage(n) {
    console.log("goto page " + n);
}
