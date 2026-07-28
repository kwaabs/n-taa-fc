const API_BASE = "/api/v1";
const GOTRUE_URL = "/gotrue";

class ApiClient {
    private getToken(): string | null {
        return localStorage.getItem("access_token");
    }

    setToken(token: string) {
        localStorage.setItem("access_token", token);
    }



    // NEW: refresh token storage
    setRefreshToken(token: string) {
        localStorage.setItem("refresh_token", token);
    }

    getRefreshToken(): string | null {
        return localStorage.getItem("refresh_token");
    }

    // NEW: store the expiry time (epoch seconds) of the current access token
    setTokenExpiry(expiresAt: number) {
        localStorage.setItem("token_expires_at", String(expiresAt));
    }


    getTokenExpiry(): number | null {
        const raw = localStorage.getItem("token_expires_at");
        return raw ? Number(raw) : null;
    }





    clearToken() {
        localStorage.removeItem("access_token");
        localStorage.removeItem("refresh_token");
        localStorage.removeItem("token_expires_at");
        localStorage.removeItem("user");
    }



    // ── Request with auto-handling of 401 ──────────────────
    private async request<T>(path: string, options: RequestInit = {}): Promise<T> {
        const token = this.getToken();
        const headers: Record<string, string> = {
            "Content-Type": "application/json",
            ...(options.headers as Record<string, string>),
        };
        if (token) {
            headers["Authorization"] = `Bearer ${token}`;
        }

        const res = await fetch(path, { ...options, headers });

        // Token expired or invalid — try reactive refresh once
        if (res.status === 401) {
            const refreshed = await this.tryRefresh();
            if (refreshed) {
                // Retry the original request with new token
                const newToken = this.getToken();
                if (newToken) {
                    headers["Authorization"] = `Bearer ${newToken}`;
                    const retryRes = await fetch(path, { ...options, headers });
                    const retryJson = await retryRes.json();
                    if (!retryRes.ok) {
                        throw new Error(retryJson.error?.message || "Request failed");
                    }
                    const r = retryJson.data !== undefined ? retryJson.data : retryJson;
                    return (r ?? []) as T;
                }
            }
            this.clearToken();
            if (!window.location.pathname.includes("/login")) {
                toast.error("Your session has expired. Please log in again.");
                window.location.replace("/login");
            }
            throw new Error("Session expired");
        }

        const json = await res.json();
        if (!res.ok) {
            throw new Error(json.error?.message || "Request failed");
        }
        const result = json.data !== undefined ? json.data : json;
        return (result ?? []) as T;
    }



    // ── Auth ───────────────────────────────────────────────
    async login(email: string, password: string) {
        const res = await fetch(`${GOTRUE_URL}/token?grant_type=password`, {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({ email, password }),
        });
        if (!res.ok) {
            const err = await res.json();
            throw new Error(err.error_description || err.msg || "Login failed");
        }
        const data = await res.json();
        this.setToken(data.access_token);
        this.setRefreshToken(data.refresh_token);
        this.setTokenExpiry(data.expires_at);
        localStorage.setItem("user", JSON.stringify(data.user));
        return data;
    }

    /**
 * Completes an OAuth sign-in by storing the tokens received from GoTrue via
 * URL hash fragment (from the /auth/callback route).
 *
 * Also fetches the user record so we have full profile info in localStorage.
 */
    async completeOAuth({
        accessToken,
        refreshToken,
        expiresAt,
    }: {
        accessToken: string;
        refreshToken: string;
        expiresAt?: number;
    }) {
        this.setToken(accessToken);
        this.setRefreshToken(refreshToken);
        if (expiresAt) {
            this.setTokenExpiry(expiresAt);
        }

        // Fetch the current user to populate localStorage['user']
        const res = await fetch(`${GOTRUE_URL}/user`, {
            headers: { Authorization: `Bearer ${accessToken}` },
        });
        if (res.ok) {
            const user = await res.json();
            localStorage.setItem("user", JSON.stringify(user));
            return user;
        }
        return null;
    }


    async signup(email: string, password: string) {
        const res = await fetch(`${GOTRUE_URL}/signup`, {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({ email, password }),
        });
        if (!res.ok) {
            const err = await res.json();
            throw new Error(err.error_description || err.msg || "Signup failed");
        }
        return res.json();
    }

    /** Authenticated FC profile (full_name, role, …). */
    getMe() {
        return this.request<{
            id: string;
            email: string;
            full_name: string;
            role: string;
            is_system_admin: boolean;
        }>(`${API_BASE}/me`);
    }

    // NEW: refresh the access token using the stored refresh token
    async tryRefresh(): Promise<boolean> {
        const refreshToken = this.getRefreshToken();
        if (!refreshToken) return false;

        try {
            const res = await fetch(`${GOTRUE_URL}/token?grant_type=refresh_token`, {
                method: "POST",
                headers: { "Content-Type": "application/json" },
                body: JSON.stringify({ refresh_token: refreshToken }),
            });
            if (!res.ok) return false;
            const data = await res.json();
            if (data.access_token) {
                this.setToken(data.access_token);
                if (data.refresh_token) {
                    this.setRefreshToken(data.refresh_token);
                }
                if (data.expires_at) {
                    this.setTokenExpiry(data.expires_at);
                }
                return true;
            }
            return false;
        } catch {
            return false;
        }
    }


    // Projects
    getProjects() {
        return this.request<any[]>(`${API_BASE}/projects`);
    }
    getProject(id: string) {
        return this.request<any>(`${API_BASE}/projects/${id}`);
    }
    createProject(data: any) {
        return this.request<any>(`${API_BASE}/projects`, {
            method: "POST",
            body: JSON.stringify(data)
        });
    }
    updateProject(id: string, data: any) {
        return this.request<any>(`${API_BASE}/projects/${id}`, {
            method: "PUT",
            body: JSON.stringify(data)
        });
    }
    archiveProject(id: string) {
        return this.request<any>(`${API_BASE}/projects/${id}/archive`, {
            method: "PATCH"
        });
    }

    // Forms
    getProjectForms(projectId: string) {
        return this.request<any[]>(`${API_BASE}/projects/${projectId}/forms`);
    }
    createForm(projectId: string, data: any) {
        return this.request<any>(`${API_BASE}/projects/${projectId}/forms`, {
            method: "POST",
            body: JSON.stringify(data)
        });
    }
    getForm(projectId: string, formId: string) {
        return this.request<any>(`${API_BASE}/projects/${projectId}/forms/${formId}`);
    }
    updateForm(projectId: string, formId: string, data: any) {
        return this.request<any>(`${API_BASE}/projects/${projectId}/forms/${formId}`, {
            method: "PUT",
            body: JSON.stringify(data)
        });
    }
    publishForm(projectId: string, formId: string, version: number) {
        return this.request<any>(`${API_BASE}/projects/${projectId}/forms/${formId}/publish`, {
            method: "POST",
            body: JSON.stringify({
                version
            })
        });
    }
    getFormVersions(projectId: string, formId: string) {
        return this.request<any[]>(`${API_BASE}/projects/${projectId}/forms/${formId}/versions`);
    }
    /** Forms from projects the user can access (for reuse as templates). */
    getFormTemplates(excludeProjectId?: string) {
        const q = excludeProjectId
            ? `?exclude_project_id=${encodeURIComponent(excludeProjectId)}`
            : "";
        return this.request<any[]>(`${API_BASE}/form-templates${q}`);
    }
    cloneForm(projectId: string, sourceFormId: string, name?: string) {
        return this.request<any>(`${API_BASE}/projects/${projectId}/forms/clone`, {
            method: "POST",
            body: JSON.stringify({
                source_form_id: sourceFormId,
                name: name || undefined,
            }),
        });
    }

    // Layers
    getProjectLayers(projectId: string) {
        return this.request<any[]>(`${API_BASE}/projects/${projectId}/layers`);
    }
    createLayer(projectId: string, data: any) {
        return this.request<any>(`${API_BASE}/projects/${projectId}/layers`, {
            method: "POST",
            body: JSON.stringify(data)
        });
    }
    deleteLayer(projectId: string, layerId: string) {
        return this.request<any>(`${API_BASE}/projects/${projectId}/layers/${layerId}`, {
            method: "DELETE"
        });
    }

    // Features
    getProjectFeatures(projectId: string, params?: {
        limit?: number; offset?: number; bbox?: string
    }) {
        const query = new URLSearchParams();
        if (params?.limit) query.set("limit", String(params.limit));
        if (params?.offset) query.set("offset", String(params.offset));
        if (params?.bbox) query.set("bbox", params.bbox);
        return this.request<any>(`${API_BASE}/projects/${projectId}/features?${query}`);
    }
    updateFeatureStatus(projectId: string, featureId: string, status: string, reviewNotes?: string) {
        return this.request<any>(`${API_BASE}/projects/${projectId}/features/${featureId}/status`, {
            method: "PATCH",
            body: JSON.stringify({
                status,
                review_notes: reviewNotes || ""
            })
        });
    }

    // Members
    getProjectMembers(projectId: string) {
        return this.request<any[]>(`${API_BASE}/projects/${projectId}/members`);
    }
    addMember(projectId: string, email: string, role: string) {
        return this.request<any>(`${API_BASE}/projects/${projectId}/members`, {
            method: "POST",
            body: JSON.stringify({
                email,
                role
            })
        });
    }
    updateMemberRole(projectId: string, userId: string, role: string) {
        return this.request<any>(`${API_BASE}/projects/${projectId}/members/${userId}`, {
            method: "PUT",
            body: JSON.stringify({
                role
            })
        });
    }
    removeMember(projectId: string, userId: string) {
        return this.request<any>(`${API_BASE}/projects/${projectId}/members/${userId}`, {
            method: "DELETE"
        });
    }

    // Choice Lists
    getProjectChoiceLists(projectId: string) {
        return this.request<any[]>(`${API_BASE}/projects/${projectId}/choice-lists`);
    }
    createChoiceList(projectId: string, data: any) {
        return this.request<any>(`${API_BASE}/projects/${projectId}/choice-lists`, {
            method: "POST",
            body: JSON.stringify(data)
        });
    }

    updateChoiceList(projectId: string, choiceListId: string, data: any) {
        return this.request<any>(
            `${API_BASE}/projects/${projectId}/choice-lists/${choiceListId}`,
            {
                method: "PUT",
                body: JSON.stringify(data),
            }
        );
    }

    deleteChoiceList(projectId: string, choiceListId: string) {
        return this.request<void>(
            `${API_BASE}/projects/${projectId}/choice-lists/${choiceListId}`,
            { method: "DELETE" }
        );
    }

    // Teams (org-level)
    getTeams() {
        return this.request<any[]>(`${API_BASE}/teams`);
    }
    createTeam(data: any) {
        return this.request<any>(`${API_BASE}/teams`, {
            method: "POST",
            body: JSON.stringify(data)
        });
    }
    getTeam(id: string) {
        return this.request<any>(`${API_BASE}/teams/${id}`);
    }
    updateTeam(id: string, data: any) {
        return this.request<any>(`${API_BASE}/teams/${id}`, {
            method: "PUT",
            body: JSON.stringify(data)
        });
    }
    deleteTeam(id: string) {
        return this.request<any>(`${API_BASE}/teams/${id}`, {
            method: "DELETE"
        });
    }
    getTeamMembers(teamId: string) {
        return this.request<any[]>(`${API_BASE}/teams/${teamId}/members`);
    }
    addTeamMember(teamId: string, email: string, role: string) {
        return this.request<any>(`${API_BASE}/teams/${teamId}/members`, {
            method: "POST",
            body: JSON.stringify({
                email,
                role
            })
        });
    }
    updateTeamMemberRole(teamId: string, userId: string, role: string) {
        return this.request<any>(`${API_BASE}/teams/${teamId}/members/${userId}`, {
            method: "PUT",
            body: JSON.stringify({
                role
            })
        });
    }
    removeTeamMember(teamId: string, userId: string) {
        return this.request<any>(`${API_BASE}/teams/${teamId}/members/${userId}`, {
            method: "DELETE"
        });
    }

    // Project Teams
    getProjectTeams(projectId: string) {
        return this.request<any[]>(`${API_BASE}/projects/${projectId}/teams`);
    }
    assignTeamToProject(projectId: string, teamId: string, role: string) {
        return this.request<any>(`${API_BASE}/projects/${projectId}/teams`, {
            method: "POST",
            body: JSON.stringify({
                team_id: teamId,
                role
            })
        });
    }
    removeTeamFromProject(projectId: string, teamId: string) {
        return this.request<any>(`${API_BASE}/projects/${projectId}/teams/${teamId}`, {
            method: "DELETE"
        });
    }

    // Users (platform admin)
	getUsers() {
		return this.request<any[]>(`${API_BASE}/users`);
	}
    getUser(userId: string) {
		return this.request<any>(`${API_BASE}/users/${userId}`);
	}
	updateUserRole(userId: string, role: string) {
		return this.request<any>(`${API_BASE}/users/${userId}/role`, {
			method: "PATCH",
			body: JSON.stringify({ role }),
		});
	}

    // Sync
    getSyncManifest(projectId: string, lastSync?: string) {
        const query = lastSync ? `?last_sync=${lastSync}` : "";
        return this.request<any>(`${API_BASE}/projects/${projectId}/sync/manifest${query}`);
    }



    // Assignments
    getProjectAssignments(projectId: string) {
        return this.request<any[]>(`${API_BASE}/projects/${projectId}/assignments`);
    }
    getAssignment(projectId: string, assignmentId: string) {
        return this.request<any>(`${API_BASE}/projects/${projectId}/assignments/${assignmentId}`);
    }
    createAssignment(projectId: string, data: any) {
        return this.request<any>(`${API_BASE}/projects/${projectId}/assignments`, {
            method: "POST",
            body: JSON.stringify(data),
        });
    }
    updateAssignment(projectId: string, assignmentId: string, data: any) {
        return this.request<any>(`${API_BASE}/projects/${projectId}/assignments/${assignmentId}`, {
            method: "PATCH",
            body: JSON.stringify(data),
        });
    }
    deleteAssignment(projectId: string, assignmentId: string) {
        return this.request<any>(`${API_BASE}/projects/${projectId}/assignments/${assignmentId}`, {
            method: "DELETE",
        });
    }
    updateAssignmentStatus(projectId: string, assignmentId: string, status: string) {
        return this.request<any>(`${API_BASE}/projects/${projectId}/assignments/${assignmentId}/status`, {
            method: "PATCH",
            body: JSON.stringify({
                status
            }),
        });
    }
    extendAssignmentDueDate(projectId: string, assignmentId: string, dueDate: string | null) {
        return this.request<any>(`${API_BASE}/projects/${projectId}/assignments/${assignmentId}/due-date`, {
            method: "PATCH",
            body: JSON.stringify({
                due_date: dueDate
            }),
        });
    }
    reassignAssignment(projectId: string, assignmentId: string, assignedTo: string | null, teamId: string | null) {
        return this.request<any>(`${API_BASE}/projects/${projectId}/assignments/${assignmentId}/reassign`, {
            method: "PATCH",
            body: JSON.stringify({
                assigned_to: assignedTo,
                team_id: teamId
            }),
        });
    }
    getAssignmentProgress(projectId: string, assignmentId: string) {
        return this.request<any>(`${API_BASE}/projects/${projectId}/assignments/${assignmentId}/progress`);
    }

    /** One-way supervisor message → team or individual (in-app notifications). */
    sendProjectMessage(
        projectId: string,
        data: { title?: string; body: string; team_id?: string; user_id?: string },
    ) {
        return this.request<{ recipient_count: number }>(
            `${API_BASE}/projects/${projectId}/messages`,
            {
                method: "POST",
                body: JSON.stringify(data),
            },
        );
    }

    // Layer detail
    getLayer(projectId: string, layerId: string) {
        return this.request<any>(`${API_BASE}/projects/${projectId}/layers/${layerId}`);
    }
    ensureLayerForm(projectId: string, layerId: string) {
        return this.request<any>(`${API_BASE}/projects/${projectId}/layers/${layerId}/ensure-form`, {
            method: "POST",
            body: JSON.stringify({}),
        });
    }
    applyLayerFormTemplate(
        projectId: string,
        layerId: string,
        sourceFormId: string,
        name?: string,
    ) {
        return this.request<any>(
            `${API_BASE}/projects/${projectId}/layers/${layerId}/apply-form-template`,
            {
                method: "POST",
                body: JSON.stringify({
                    source_form_id: sourceFormId,
                    name: name || undefined,
                }),
            },
        );
    }
    updateLayer(projectId: string, layerId: string, data: any) {
        return this.request<any>(`${API_BASE}/projects/${projectId}/layers/${layerId}`, {
            method: "PUT",
            body: JSON.stringify(data),
        });
    }
    getLayerChangeSummary(projectId: string, layerId: string) {
        return this.request<any>(`${API_BASE}/projects/${projectId}/layers/${layerId}/summary`);
    }

    // Data sources
    getLayerDataSources(projectId: string, layerId: string) {
        return this.request<any[]>(`${API_BASE}/projects/${projectId}/layers/${layerId}/data-sources`);
    }
    createDataSource(projectId: string, layerId: string, data: any) {
        return this.request<any>(`${API_BASE}/projects/${projectId}/layers/${layerId}/data-sources`, {
            method: "POST",
            body: JSON.stringify(data),
        });
    }
    uploadDataSourceFile(projectId: string, layerId: string, file: File, name: string, format: string) {
        const formData = new FormData();
        formData.append("file", file);
        formData.append("name", name);
        formData.append("format", format);
        const token = localStorage.getItem("access_token");
        return fetch(`${API_BASE}/projects/${projectId}/layers/${layerId}/data-sources/upload`, {
            method: "POST",
            headers: {
                Authorization: `Bearer ${token}`
            },
            body: formData,
        }).then(async (res) => {
            const json = await res.json();
            if (!res.ok) throw new Error(json.error?.message || "Upload failed");
            return json.data ?? json;
        });
    }
    syncDataSource(projectId: string, layerId: string, sourceId: string) {
        return this.request<any>(`${API_BASE}/projects/${projectId}/layers/${layerId}/data-sources/${sourceId}/sync`, {
            method: "POST",
        });
    }
    deleteDataSource(projectId: string, layerId: string, sourceId: string) {
        return this.request<any>(`${API_BASE}/projects/${projectId}/layers/${layerId}/data-sources/${sourceId}`, {
            method: "DELETE",
        });
    }

    linkDataSourceConnection(
        projectId: string,
        layerId: string,
        sourceId: string,
        connectionId: string | null,
    ) {
        return this.request<any>(
            `${API_BASE}/projects/${projectId}/layers/${layerId}/data-sources/${sourceId}/connection`,
            {
                method: "PATCH",
                body: JSON.stringify({ connection_id: connectionId }),
            }
        );
    }

    // ── Reconciliation ─────────────────────────────────────

    previewReconciliation(
        projectId: string,
        layerId: string,
        sourceId: string,
        batchSize?: number,
        featureIds?: string[],
    ) {
        const body: Record<string, unknown> = {};
        if (batchSize) body.batch_size = batchSize;
        if (featureIds?.length) body.feature_ids = featureIds;
        return this.request<any>(
            `${API_BASE}/projects/${projectId}/layers/${layerId}/data-sources/${sourceId}/reconcile/preview`,
            {
                method: "POST",
                body: JSON.stringify(body),
            }
        );
    }

    applyReconciliation(
        projectId: string,
        layerId: string,
        sourceId: string,
        batchSize?: number,
        featureIds?: string[],
        acknowledgments?: string[],
    ) {
        const body: Record<string, unknown> = {};
        if (batchSize) body.batch_size = batchSize;
        if (featureIds?.length) body.feature_ids = featureIds;
        if (acknowledgments?.length) body.acknowledgments = acknowledgments;
        return this.request<any>(
            `${API_BASE}/projects/${projectId}/layers/${layerId}/data-sources/${sourceId}/reconcile/apply`,
            {
                method: "POST",
                body: JSON.stringify(body),
            }
        );
    }

    writeBackFeature(projectId: string, layerId: string, featureId: string) {
        return this.request<{
            job_id: string;
            feature_id: string;
            source_ref: string;
            change_type: string;
            outcome: "applied" | "conflict" | "skipped" | "failed";
            reason?: string;
            conflict_id?: string;
        }>(
            `${API_BASE}/projects/${projectId}/layers/${layerId}/features/${featureId}/write-back`,
            { method: "POST" }
        );
    }

    getReconciliationJob(projectId: string, jobId: string) {
        return this.request<any>(
            `${API_BASE}/projects/${projectId}/reconcile/jobs/${jobId}`
        );
    }

    cancelReconciliationJob(projectId: string, jobId: string) {
        return this.request<any>(
            `${API_BASE}/projects/${projectId}/reconcile/jobs/${jobId}/cancel`,
            { method: "POST" }
        );
    }

    getReconciliationJobLog(projectId: string, jobId: string, limit = 100) {
        return this.request<any>(
            `${API_BASE}/projects/${projectId}/reconcile/jobs/${jobId}/log?limit=${limit}`
        );
    }

    listReconciliationConflicts(projectId: string, layerId: string) {
        return this.request<any>(
            `${API_BASE}/projects/${projectId}/layers/${layerId}/reconcile/conflicts`
        );
    }

    resolveReconciliationConflict(
        projectId: string,
        conflictId: string,
        data: { resolution: string; resolved_attrs?: any; notes?: string },
    ) {
        return this.request<any>(
            `${API_BASE}/projects/${projectId}/reconcile/conflicts/${conflictId}/resolve`,
            {
                method: "POST",
                body: JSON.stringify(data),
            }
        );
    }

    forceFinalizeReconciliationJob(projectId: string, jobId: string) {
        return this.request<any>(
            `${API_BASE}/projects/${projectId}/reconcile/jobs/${jobId}/force-finalize`,
            { method: "POST" }
        );
    }

    getReconciliationSummary(projectId: string, layerId: string) {
        return this.request<any>(
            `${API_BASE}/projects/${projectId}/layers/${layerId}/reconcile/summary`
        );
    }

    // Layer style
    getLayerStyle(projectId: string, layerId: string) {
        return this.request<any>(`${API_BASE}/projects/${projectId}/layers/${layerId}/style`);
    }
    updateLayerStyle(projectId: string, layerId: string, style: any) {
        return this.request<any>(`${API_BASE}/projects/${projectId}/layers/${layerId}/style`, {
            method: "PUT",
            body: JSON.stringify(style),
        });
    }

    /** Shared geo/FC map symbols (pole, transformer, …). */
    listMapSymbols() {
        return this.request<{ name: string; ref: string; svg: string }[]>(
            `${API_BASE}/app/symbols`,
        );
    }

    getFeature(projectId: string, featureId: string) {
        return this.request<any>(
            `${API_BASE}/projects/${projectId}/features/${featureId}`,
            { method: "GET" }
        );
    }

    // Icon upload
    uploadIcon(projectId: string, file: File) {
        const formData = new FormData();
        formData.append("file", file);
        const token = localStorage.getItem("access_token");
        return fetch(`${API_BASE}/projects/${projectId}/icons`, {
            method: "POST",
            headers: {
                Authorization: `Bearer ${token}`
            },
            body: formData,
        }).then(async (res) => {
            const json = await res.json();
            if (!res.ok) throw new Error(json.error?.message || "Upload failed");
            return json.data ?? json;
        });
    }

    // Project connections
    getProjectConnections(projectId: string) {
        return this.request<any[]>(`${API_BASE}/projects/${projectId}/connections`);
    }
    saveProjectConnection(projectId: string, data: any) {
        return this.request<any>(`${API_BASE}/projects/${projectId}/connections`, {
            method: "POST",
            body: JSON.stringify(data),
        });
    }
    deleteProjectConnection(projectId: string, connectionId: string) {
        return this.request<any>(`${API_BASE}/projects/${projectId}/connections/${connectionId}`, {
            method: "DELETE",
        });
    }

    // Import wizard
    getHomeConnection(projectId: string) {
        return this.request<{
            host: string;
            port: number;
            database: string;
            username: string;
            password: string;
            ssl_mode: string;
        }>(`${API_BASE}/projects/${projectId}/import/home-connection`);
    }
    testConnection(projectId: string, body: any) {
        return this.request<any>(`${API_BASE}/projects/${projectId}/import/test-connection`, {
            method: "POST",
            body: JSON.stringify(body),
        });
    }
    discoverTables(projectId: string, body: any) {
        return this.request<any>(`${API_BASE}/projects/${projectId}/import/discover`, {
            method: "POST",
            body: JSON.stringify(body),
        });
    }
    createImportJob(projectId: string, body: any) {
        return this.request<any>(`${API_BASE}/projects/${projectId}/import/jobs`, {
            method: "POST",
            body: JSON.stringify(body),
        });
    }
    getImportJob(projectId: string, jobId: string) {
        return this.request<any>(`${API_BASE}/projects/${projectId}/import/jobs/${jobId}`);
    }
    listImportJobs(projectId: string) {
        return this.request<any[]>(`${API_BASE}/projects/${projectId}/import/jobs`);
    }

    // Layer publishing
    publishLayer(projectId: string, layerId: string) {
        return this.request<any>(
            `${API_BASE}/projects/${projectId}/layers/${layerId}/publish`, {
            method: "POST"
        }
        );
    }
    unpublishLayer(projectId: string, layerId: string) {
        return this.request<any>(
            `${API_BASE}/projects/${projectId}/layers/${layerId}/unpublish`, {
            method: "POST"
        }
        );
    }

    // Layer features (filtered by layer_id)
    getLayerFeatures(
        projectId: string,
        layerId: string,
        params?: {
            limit?: number; offset?: number
        }
    ) {
        const query = new URLSearchParams();
        query.set("layer_id", layerId);
        if (params?.limit) query.set("limit", String(params.limit));
        if (params?.offset) query.set("offset", String(params.offset));
        return this.request<any>(
            `${API_BASE}/projects/${projectId}/features?${query}`
        );
    }
    buildAOIFromLayer(
        projectId: string,
        body: { layer_id: string; source_refs: string[] },
    ) {
        return this.request<{
            geometry: any;
            layer_id: string;
            source_refs: string[];
            row_count: number;
        }>(`${API_BASE}/projects/${projectId}/aoi/from-layer`, {
            method: "POST",
            body: JSON.stringify(body),
        });
    }

    getLinkedLayerRows(
        projectId: string,
        layerId: string,
        params?: {
            limit?: number;
            offset?: number;
            q?: string;
            filters?: { field: string; op: string; value: string }[];
        }
    ) {
        const query = new URLSearchParams();
        if (params?.limit) query.set("limit", String(params.limit));
        if (params?.offset) query.set("offset", String(params.offset));
        if (params?.q?.trim()) query.set("q", params.q.trim());
        if (params?.filters?.length) {
            query.set("filters", JSON.stringify(params.filters));
        }
        const qs = query.toString();
        return this.request<any>(
            `${API_BASE}/projects/${projectId}/layers/${layerId}/rows${qs ? `?${qs}` : ""}`
        );
    }
    dispatchProject(projectId: string) {
        return this.request<any>(
            `${API_BASE}/projects/${projectId}/dispatch`, {
            method: "POST"
        }
        );
    }

    // Attachments
    listFeatureAttachments(projectId: string, featureId: string) {
        return this.request<any[]>(
            `${API_BASE}/projects/${projectId}/features/${featureId}/attachments`
        );
    }
    getAttachment(attachmentId: string) {
        return this.request<any>(`${API_BASE}/attachments/${attachmentId}`);
    }
    createAttachment(projectId: string, body: any) {
        return this.request<any>(`${API_BASE}/projects/${projectId}/attachments`, {
            method: "POST",
            body: JSON.stringify(body),
        });
    }
    confirmAttachment(attachmentId: string) {
        return this.request<any>(
            `${API_BASE}/attachments/${attachmentId}/confirm`,
            { method: "POST" }
        );
    }
    deleteAttachment(attachmentId: string) {
        return this.request<any>(`${API_BASE}/attachments/${attachmentId}`, {
            method: "DELETE",
        });
    }

    // Bundle
    requestBundle(projectId: string, includeReferenceData: boolean) {
        const q = new URLSearchParams();
        q.set("reference_data", includeReferenceData ? "true" : "false");
        return this.request<any>(
            `${API_BASE}/projects/${projectId}/bundle?${q}`
        );
    }

    getBundleJob(projectId: string, jobId: string) {
        return this.request<any>(
            `${API_BASE}/projects/${projectId}/bundle/jobs/${jobId}`
        );
    }





}



export const api = new ApiClient();