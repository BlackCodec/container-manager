namespace ContainerManager {

	public class PodmanManager {

		/* Container methods */
		public static ContainerStatus get_container_status(string name) {
			string base_cmd="podman ps --quiet --filter name=%s --filter status=%s";
			foreach (ContainerStatus status in ContainerStatus.values()) {
				string out = Utils.exec(base_cmd.printf(name,status.value()));
				if (out != "") return status;
			}
			return ContainerStatus.UNKNOWN;
		}

		public static bool delete_container(string name) {
			int stop = Posix.system("podman stop %s ".printf(name));
			if (stop == 0) {
				int delete = Posix.system("podman rm %s ".printf(name));
				return delete == 0;
			}
			return false;
		}

		public static bool pause_container(string name) {
			int result = Posix.system("podman pause %s ".printf(name));
			return (result == 0 && PodmanManager.get_container_status(name) == ContainerStatus.PAUSED);
		}

		public static bool resume_container(string name) {
			int result = Posix.system("podman unpause %s ".printf(name));
			return (result == 0 && PodmanManager.get_container_status(name) == ContainerStatus.RUNNING);
		}


		/* Image methods */
		public static string? get_image_id(string name) {
			string out = Utils.exec("podman images %s --format={{.Id}}".printf(name));
			return (out == "")?null:out;
		}

		public static string? get_image_name(string id) { 
			string out = Utils.exec("podman images --filter id=%s --format={{.Repository}}:{{.Tag}}".printf(id));
			return (out == "")?null:out;
		}
		
		public static HashTable<string,string> get_image_list() {
			Logger.entering("PodmanManager","get_image_list");
			HashTable<string,string> result = new HashTable<string,string>(str_hash,str_equal);
			string response_exec = Utils.exec_multi("podman images --format='{{.Id}};{{.Repository}}:{{.Tag}}'");
			if (response_exec != null && response_exec != "") {
				Logger.log(Level.FINEST, "Retrieved output: {0}", new string[] { response_exec });
				string[] lines = response_exec.split("\n");
				foreach (string line in lines) {
					if (line.replace("\n","").length == 0) continue;
					string id = line.split(";")[0];
					Logger.log(Level.FINEST, "ID: {0}", new string[] { id });
					string name = line.split(";")[1];
					Logger.log(Level.FINEST, "Name: {0}", new string[] { name });
					string[] f_name=name.split("/");
					string clear_name=f_name[f_name.length-1];
					Logger.log(Level.FINEST, "Add record {0} -> {1}", new string[] { clear_name, id});  
					result.insert(clear_name,id);
				}
			}
			Logger.exiting("PodmanManager","get_image_list");
			return result;
		}
	}
}
