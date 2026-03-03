import { useState } from "react";
import { useNavigate } from "react-router-dom";
import { Briefcase, Plus, Star } from "lucide-react";
import { format } from "date-fns";
import { useProjectStore } from "@/stores/projectStore";
import { useToastStore } from "@/stores/toastStore";
import { CreateProjectModal } from "@/components/features/CreateProjectModal";

export function MobileProjectsPage() {
  const navigate = useNavigate();
  const projects = useProjectStore((s) => s.projects) || [];
  const createProject = useProjectStore((s) => s.createProject);
  const { success, error } = useToastStore();
  const [showCreateModal, setShowCreateModal] = useState(false);

  const starred = projects.filter((p) => p.starred);
  const unstarred = projects.filter((p) => !p.starred);

  const handleCreateProject = async (data: {
    name: string;
    description?: string;
    memberIds: string[];
  }) => {
    try {
      const project = await createProject(data);
      success("Project created successfully");
      setShowCreateModal(false);
      navigate(`/projects/${project.id}`);
    } catch (err) {
      error("Error: " + (err as Error).message);
    }
  };

  const renderCard = (project: (typeof projects)[0]) => (
    <div
      key={project.id}
      onClick={() => navigate(`/projects/${project.id}`)}
      className="p-4 bg-dark-surface border border-dark-border rounded-lg hover:border-blue-500 transition-colors cursor-pointer flex items-center gap-3"
    >
      <Briefcase size={18} className="text-blue-400 flex-shrink-0" />
      <div className="flex-1 min-w-0">
        <h3 className="font-medium text-dark-text truncate">{project.name}</h3>
        <p className="text-xs text-dark-text-muted mt-1 truncate">
          {project.description
            ? project.description
            : project.createdBy
              ? `by ${project.createdBy.name} · ${format(new Date(project.insertedAt), "MMM d, yyyy")}`
              : format(new Date(project.insertedAt), "MMM d, yyyy")}
        </p>
      </div>
      {project.starred && (
        <Star
          size={14}
          className="fill-yellow-400 text-yellow-400 flex-shrink-0"
        />
      )}
    </div>
  );

  return (
    <div className="flex-1 flex flex-col">
      <div className="px-4 py-3 border-b border-dark-border flex items-center justify-between">
        <h1 className="text-lg font-semibold text-dark-text">Projects</h1>
        <button
          onClick={() => setShowCreateModal(true)}
          className="p-2 text-dark-text-muted hover:text-dark-text transition-colors"
        >
          <Plus size={20} />
        </button>
      </div>
      <div className="flex-1 overflow-y-auto p-4">
        {starred.length > 0 && (
          <div className="pb-1 mb-2 text-xs font-semibold text-dark-text-muted uppercase tracking-wider flex items-center gap-1.5">
            <Star size={12} />
            Starred
          </div>
        )}
        {starred.length > 0 && (
          <div className="space-y-2 mb-4">{starred.map(renderCard)}</div>
        )}
        {starred.length > 0 && unstarred.length > 0 && (
          <div className="pb-1 mb-2 text-xs font-semibold text-dark-text-muted uppercase tracking-wider">
            All Projects
          </div>
        )}
        <div className="space-y-2">{unstarred.map(renderCard)}</div>
        {projects.length === 0 && (
          <div className="py-8 text-center text-dark-text-muted text-sm">
            No projects yet
          </div>
        )}
      </div>
      <CreateProjectModal
        isOpen={showCreateModal}
        onClose={() => setShowCreateModal(false)}
        onSubmit={handleCreateProject}
      />
    </div>
  );
}
