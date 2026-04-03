package beap.platforms;

import beap.Config;

interface Platform {
    function getName():String;
    function getDescription():String;
    function build(config:Config):Bool;
    function run(config:Config):Void;
    function isAvailable():Bool;
}