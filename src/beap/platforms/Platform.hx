package beap.platforms;

import beap.Config;

/**
 * Platform interface for SDL-aware build targets
 */
interface Platform {
    function getName():String;
    function getDescription():String;
    function isAvailable():Bool;
    function build(config:Config, ?consoleMode:Bool = false):Bool;
    function run(config:Config, ?showOutput:Bool = false):Void;
}
