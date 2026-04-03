package beap.commands;

import beap.Config;

interface Command {
    function execute(args:Array<String>):Void;
}

abstract class BaseCommand implements Command {
    private var config:Config;
    
    public function new(config:Config) {
        this.config = config;
    }
    
    public function execute(args:Array<String>):Void {
        // Override in subclasses
    }
}