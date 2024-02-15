namespace ContainerManager {

	public enum Level {
		OFF, ALL, SEVERE, WARNING, INFO, FINE, FINER, FINEST;

		public static Level[] values() { return { OFF,ALL,SEVERE,WARNING,INFO,FINE,FINER,FINEST }; }

		public string name() { return this.to_string().down().replace("container_manager_level_",""); }
		public int int_value() { 
			switch (this) {
				case OFF: return 0;
				case ALL: return 100;
				case SEVERE: return 1;
				case WARNING: return 2;
				case INFO: return 3;
				case FINE: return 4;
				case FINER: return 5;
				case FINEST: return 6;
				default: return 999;
			}
		}

		public static Level get(string value) {
			foreach (Level l in Level.values()) {
				if (l.name() == value.down()) return l;
			}
			return Level.OFF;
		}
	}

	public interface LogHandler : Object {
		public abstract void logp(Level level, string className, string methodName, string message);
	}

	public class SysoutHandler : LogHandler, Object {

		public SysoutHandler() {}
		public void logp(Level level, string className, string methodName, string message) {
			stdout.printf("<%s> [%s] %s.%s: %s\n", new DateTime.now_local().to_string(), level.name().up(), className, methodName, message);
		}
	}

	public class Caller {

		private Caller parent = null;
		private string className;
		private string methodName;

		public Caller(string className, string methodName) {
			this.className = className;
			this.methodName = methodName;
		}
		
		public string get_class_name() { return this.className; }
		public string get_method_name() { return this.methodName; }
		public Caller? get_parent() { return this.parent; }

		public bool has_parent() { return this.parent != null; }

		public void set_parent(Caller parent) { this.parent = parent; }

	}

	public class Logger {

		private static Level level = Level.SEVERE;
		private static Caller current = null;
		private static LogHandler handler = null; 


		private static bool is_loggable(Level level) { return Logger.level.int_value() >= level.int_value(); }

		public static void set_level(Level level) { Logger.level = level; }

		public static void entering(string className, string methodName) {
			string message = "Entering in %s.%s".printf(className, methodName);
			Logger.finest(message);
			Caller caller = new Caller(className,methodName);
			if (Logger.current != null) caller.set_parent(Logger.current);
			Logger.current=caller;
		}

		public static void exiting(string className, string methodName) {
			string message = "Exiting from %s.%s".printf(className, methodName);
			Logger.finest(message);
			if (Logger.current != null && Logger.current.has_parent()) Logger.current = Logger.current.get_parent();
			else Logger.current = new Caller("Logger","__new__");
		}

		public static void logp(string className, string methodName, Level level, string message) {
			if (current == null) current = new Caller("Logger","logp");
			if (handler == null) handler = new SysoutHandler();
			if (Logger.is_loggable(level)) Logger.handler.logp(level,className, methodName, message);
		}


		public static void finest(string message) { Logger.log(Level.FINEST, message, null); }
		public static void finer(string message) { Logger.log(Level.FINER, message, null); }
		public static void fine(string message) { Logger.log(Level.FINE, message, null); }
		public static void info(string message) { Logger.log(Level.INFO, message, null); }
		public static void warn(string message) { Logger.log(Level.WARNING, message, null); }
		public static void severe(string message) { Logger.log(Level.SEVERE, message, null); }
		public static void stack_trace(Error e) { Logger.log(Level.SEVERE, "Error: {0}", new string[] {e.message}); }

		public static void log(Level level, string message, string[]? datas) {
			if (Logger.is_loggable(level)) {
				string msg = message;
				if (datas != null) {
					int i = 0;
					while (i < datas.length) {
						msg = msg.replace("{%d}".printf(i), datas[i]);
						i++;
					}
				}
				Logger.logp(Logger.current.get_class_name(), Logger.current.get_method_name(),level, msg);
			}
		}
	}
}