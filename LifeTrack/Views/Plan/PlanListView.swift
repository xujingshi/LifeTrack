import SwiftUI

// MARK: - 规划列表视图
struct PlanListView: View {
    @State private var plans: [PlanWithProgress] = []
    @State private var isLoading = false
    @State private var showAddPlan = false
    @State private var selectedPlanId: Int?
    @State private var errorMessage: String?
    @State private var showArchived = false

    // 记住上次打开的规划
    @AppStorage("lastOpenedPlanId") private var lastOpenedPlanId: Int = 0

    var body: some View {
        NavigationStack {
            Group {
                if isLoading && plans.isEmpty {
                    ProgressView("加载中...")
                } else if plans.isEmpty {
                    emptyView
                } else {
                    planList
                }
            }
            .navigationTitle("规划")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showAddPlan = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }

                ToolbarItem(placement: .navigationBarLeading) {
                    Menu {
                        Toggle("显示已归档", isOn: $showArchived)
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                    }
                }
            }
            .sheet(isPresented: $showAddPlan) {
                AddPlanView { plan in
                    // 创建成功后刷新列表
                    Task {
                        await loadPlans()
                    }
                }
            }
            .navigationDestination(for: Int.self) { planId in
                PlanDetailView(planId: planId)
            }
            .task {
                await loadPlans()
            }
            .onChange(of: showArchived) { _ in
                Task {
                    await loadPlans()
                }
            }
        }
    }

    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "folder")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            Text("暂无规划")
                .foregroundColor(.gray)
            Button("创建规划") {
                showAddPlan = true
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var planList: some View {
        List {
            ForEach(plans) { plan in
                NavigationLink(value: plan.id) {
                    PlanRowView(plan: plan)
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        Task {
                            await deletePlan(id: plan.id)
                        }
                    } label: {
                        Label("删除", systemImage: "trash")
                    }

                    Button {
                        Task {
                            await archivePlan(id: plan.id, archive: !plan.isArchived)
                        }
                    } label: {
                        Label(plan.isArchived ? "取消归档" : "归档", systemImage: plan.isArchived ? "tray.and.arrow.up" : "archivebox")
                    }
                    .tint(.orange)
                }
            }
        }
        .refreshable {
            await loadPlans()
        }
    }

    private func loadPlans() async {
        isLoading = true
        do {
            plans = try await PlanService.shared.getPlans(includeArchived: showArchived)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func deletePlan(id: Int) async {
        do {
            try await PlanService.shared.deletePlan(id: id)
            plans.removeAll { $0.id == id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func archivePlan(id: Int, archive: Bool) async {
        do {
            let request = UpdatePlanRequest(name: nil, description: nil, icon: nil, color: nil, isArchived: archive)
            _ = try await PlanService.shared.updatePlan(id: id, request)
            await loadPlans()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - 规划行视图
struct PlanRowView: View {
    let plan: PlanWithProgress

    var body: some View {
        HStack(spacing: 12) {
            // 图标
            Text(plan.icon)
                .font(.title)
                .frame(width: 44, height: 44)
                .background(Color(hex: plan.color).opacity(0.15))
                .cornerRadius(10)

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(plan.name)
                        .font(.headline)

                    if plan.isArchived {
                        Text("已归档")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(4)
                    }
                }

                if !plan.description.isEmpty {
                    Text(plan.description)
                        .font(.caption)
                        .foregroundColor(.gray)
                        .lineLimit(1)
                }

                // 进度条
                HStack(spacing: 8) {
                    ProgressView(value: plan.progress)
                        .tint(Color(hex: plan.color))

                    Text("\(plan.completedTasks)/\(plan.totalTasks)")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - 规划详情视图
struct PlanDetailView: View {
    let planId: Int

    @State private var plan: Plan?
    @State private var isLoading = false
    @State private var showAddTask = false
    @State private var showEditPlan = false
    @State private var editingTask: PlanTask?
    @State private var addSubTaskParentId: Int?
    @State private var errorMessage: String?

    // 记住上次打开的规划
    @AppStorage("lastOpenedPlanId") private var lastOpenedPlanId: Int = 0

    var body: some View {
        Group {
            if isLoading && plan == nil {
                ProgressView("加载中...")
            } else if let plan = plan {
                taskListView(plan: plan)
            } else {
                Text("规划不存在")
                    .foregroundColor(.gray)
            }
        }
        .navigationTitle(plan?.name ?? "规划详情")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showAddTask = true
                } label: {
                    Image(systemName: "plus")
                }
            }

            ToolbarItem(placement: .secondaryAction) {
                Button {
                    showEditPlan = true
                } label: {
                    Label("编辑规划", systemImage: "pencil")
                }
            }
        }
        .sheet(isPresented: $showAddTask) {
            if let plan = plan {
                AddTaskView(planId: plan.id) { _ in
                    Task {
                        await loadPlan()
                    }
                }
            }
        }
        .sheet(isPresented: $showEditPlan) {
            if let plan = plan {
                EditPlanView(plan: plan) { _ in
                    Task {
                        await loadPlan()
                    }
                }
            }
        }
        .sheet(item: $editingTask) { task in
            EditTaskView(task: task) { _ in
                Task {
                    await loadPlan()
                }
            }
        }
        .sheet(isPresented: Binding(
            get: { addSubTaskParentId != nil },
            set: { if !$0 { addSubTaskParentId = nil } }
        )) {
            if let plan = plan, let parentId = addSubTaskParentId {
                AddTaskView(planId: plan.id, parentId: parentId) { _ in
                    Task {
                        await loadPlan()
                    }
                }
            }
        }
        .task {
            lastOpenedPlanId = planId
            await loadPlan()
        }
    }

    @ViewBuilder
    private func taskListView(plan: Plan) -> some View {
        let tasks = plan.tasks ?? []

        if tasks.isEmpty {
            VStack(spacing: 16) {
                Image(systemName: "checklist")
                    .font(.system(size: 60))
                    .foregroundColor(.gray)
                Text("暂无任务")
                    .foregroundColor(.gray)
                Button("添加任务") {
                    showAddTask = true
                }
                .buttonStyle(.borderedProminent)
            }
        } else {
            List {
                ForEach(tasks) { task in
                    // 父任务
                    TaskRowView(task: task, planColor: plan.color) {
                        await toggleTaskStatus(task: task)
                    } onEdit: {
                        editingTask = task
                    } onAddSubTask: {
                        addSubTaskParentId = task.id
                    } onDelete: {
                        await deleteTask(id: task.id)
                    }

                    // 子任务
                    if let subTasks = task.subTasks, !subTasks.isEmpty {
                        ForEach(subTasks) { subTask in
                            TaskRowView(task: subTask, planColor: plan.color, isSubTask: true) {
                                await toggleTaskStatus(task: subTask)
                            } onEdit: {
                                editingTask = subTask
                            } onDelete: {
                                await deleteTask(id: subTask.id)
                            }
                        }
                    }
                }
            }
            .refreshable {
                await loadPlan()
            }
        }
    }

    private func loadPlan() async {
        isLoading = true
        do {
            plan = try await PlanService.shared.getPlan(id: planId)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func toggleTaskStatus(task: PlanTask) async {
        let newStatus = task.status == TaskStatus.done.rawValue ? TaskStatus.todo.rawValue : TaskStatus.done.rawValue
        do {
            try await PlanService.shared.updateTaskStatus(id: task.id, status: newStatus)
            await loadPlan()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func deleteTask(id: Int) async {
        do {
            try await PlanService.shared.deleteTask(id: id)
            await loadPlan()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - 任务行视图
struct TaskRowView: View {
    let task: PlanTask
    let planColor: String
    var isSubTask: Bool = false
    let onToggle: () async -> Void
    let onEdit: () -> Void
    var onAddSubTask: (() -> Void)? = nil
    let onDelete: () async -> Void

    var body: some View {
        HStack(spacing: 12) {
            // 状态图标
            Button {
                Task {
                    await onToggle()
                }
            } label: {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundColor(task.isCompleted ? Color(hex: planColor) : .gray)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 4) {
                Text(task.title)
                    .font(isSubTask ? .subheadline : .headline)
                    .strikethrough(task.isCompleted)
                    .foregroundColor(task.isCompleted ? .gray : .primary)

                HStack(spacing: 8) {
                    // 优先级
                    if task.priority > 0 {
                        Text(task.priorityLevel.title)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(priorityColor.opacity(0.2))
                            .foregroundColor(priorityColor)
                            .cornerRadius(4)
                    }

                    // 截止日期
                    if let dueDate = task.dueDate, !dueDate.isEmpty, !dueDate.hasPrefix("0001") {
                        HStack(spacing: 2) {
                            Image(systemName: "calendar")
                                .font(.caption2)
                            Text(formatDate(dueDate))
                                .font(.caption2)
                        }
                        .foregroundColor(isOverdue(dueDate) && !task.isCompleted ? .red : .gray)
                    }

                    // 子任务数量
                    if let subTasks = task.subTasks, !subTasks.isEmpty {
                        HStack(spacing: 2) {
                            Image(systemName: "list.bullet")
                                .font(.caption2)
                            Text("\(subTasks.filter { $0.isCompleted }.count)/\(subTasks.count)")
                                .font(.caption2)
                        }
                        .foregroundColor(.gray)
                    }
                }
            }

            Spacer()

            // 添加子任务按钮（仅父任务显示）
            if !isSubTask, let onAddSubTask = onAddSubTask {
                Button {
                    onAddSubTask()
                } label: {
                    Image(systemName: "plus")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .padding(8)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.leading, isSubTask ? 32 : 0)
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            onEdit()
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                Task {
                    await onDelete()
                }
            } label: {
                Label("删除", systemImage: "trash")
            }

            Button {
                onEdit()
            } label: {
                Label("编辑", systemImage: "pencil")
            }
            .tint(.blue)
        }
        .contextMenu {
            Button {
                onEdit()
            } label: {
                Label("编辑", systemImage: "pencil")
            }

            if !isSubTask, let onAddSubTask = onAddSubTask {
                Button {
                    onAddSubTask()
                } label: {
                    Label("添加子任务", systemImage: "plus.circle")
                }
            }

            Divider()

            Button(role: .destructive) {
                Task {
                    await onDelete()
                }
            } label: {
                Label("删除", systemImage: "trash")
            }
        }
    }

    private var priorityColor: Color {
        switch task.priority {
        case 1: return .orange
        case 2: return .red
        default: return .green
        }
    }

    private func parseDate(_ dateString: String) -> Date? {
        // 尝试 ISO 8601 格式 (2026-03-01T00:00:00Z)
        let isoFormatter = ISO8601DateFormatter()
        if let date = isoFormatter.date(from: dateString) {
            return date
        }
        // 尝试简单日期格式 (2026-03-01)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: dateString)
    }

    private func formatDate(_ dateString: String) -> String {
        if let date = parseDate(dateString) {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy/MM/dd"
            return formatter.string(from: date)
        }
        return dateString
    }

    private func isOverdue(_ dateString: String) -> Bool {
        if let date = parseDate(dateString) {
            return date < Date()
        }
        return false
    }
}

// MARK: - 添加规划视图
struct AddPlanView: View {
    @Environment(\.dismiss) var dismiss
    @State private var name = ""
    @State private var description = ""
    @State private var icon = "📋"
    @State private var color = "#007AFF"
    @State private var isLoading = false
    @State private var errorMessage: String?

    let icons = ["📋", "📚", "💼", "🎯", "💪", "🏃", "🎨", "🎵", "✈️", "🏠", "💰", "❤️"]
    let colors = ["#007AFF", "#34C759", "#FF9500", "#FF3B30", "#AF52DE", "#5856D6", "#FF2D55", "#00C7BE"]

    var onAdd: (Plan) -> Void

    var body: some View {
        NavigationView {
            Form {
                Section("基本信息") {
                    TextField("规划名称", text: $name)

                    TextField("描述（可选）", text: $description, axis: .vertical)
                        .lineLimit(3...5)
                }

                Section("图标") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 12) {
                        ForEach(icons, id: \.self) { emoji in
                            Text(emoji)
                                .font(.title)
                                .frame(width: 44, height: 44)
                                .background(icon == emoji ? Color.blue.opacity(0.2) : Color.clear)
                                .cornerRadius(8)
                                .onTapGesture {
                                    icon = emoji
                                }
                        }
                    }
                    .padding(.vertical, 8)
                }

                Section("主题色") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 8), spacing: 12) {
                        ForEach(colors, id: \.self) { hex in
                            Circle()
                                .fill(Color(hex: hex))
                                .frame(width: 32, height: 32)
                                .overlay(
                                    Circle()
                                        .stroke(Color.primary, lineWidth: color == hex ? 3 : 0)
                                )
                                .onTapGesture {
                                    color = hex
                                }
                        }
                    }
                    .padding(.vertical, 8)
                }

                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("新建规划")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("创建") {
                        Task {
                            await savePlan()
                        }
                    }
                    .disabled(name.isEmpty || isLoading)
                }
            }
        }
    }

    private func savePlan() async {
        isLoading = true
        let request = CreatePlanRequest(
            name: name,
            description: description.isEmpty ? nil : description,
            icon: icon,
            color: color
        )

        do {
            let plan = try await PlanService.shared.createPlan(request)
            onAdd(plan)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

// MARK: - 编辑规划视图
struct EditPlanView: View {
    @Environment(\.dismiss) var dismiss
    let plan: Plan
    @State private var name: String
    @State private var description: String
    @State private var icon: String
    @State private var color: String
    @State private var isLoading = false
    @State private var errorMessage: String?

    let icons = ["📋", "📚", "💼", "🎯", "💪", "🏃", "🎨", "🎵", "✈️", "🏠", "💰", "❤️"]
    let colors = ["#007AFF", "#34C759", "#FF9500", "#FF3B30", "#AF52DE", "#5856D6", "#FF2D55", "#00C7BE"]

    var onUpdate: (Plan) -> Void

    init(plan: Plan, onUpdate: @escaping (Plan) -> Void) {
        self.plan = plan
        self.onUpdate = onUpdate
        _name = State(initialValue: plan.name)
        _description = State(initialValue: plan.description)
        _icon = State(initialValue: plan.icon)
        _color = State(initialValue: plan.color)
    }

    var body: some View {
        NavigationView {
            Form {
                Section("基本信息") {
                    TextField("规划名称", text: $name)

                    TextField("描述（可选）", text: $description, axis: .vertical)
                        .lineLimit(3...5)
                }

                Section("图标") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 12) {
                        ForEach(icons, id: \.self) { emoji in
                            Text(emoji)
                                .font(.title)
                                .frame(width: 44, height: 44)
                                .background(icon == emoji ? Color.blue.opacity(0.2) : Color.clear)
                                .cornerRadius(8)
                                .onTapGesture {
                                    icon = emoji
                                }
                        }
                    }
                    .padding(.vertical, 8)
                }

                Section("主题色") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 8), spacing: 12) {
                        ForEach(colors, id: \.self) { hex in
                            Circle()
                                .fill(Color(hex: hex))
                                .frame(width: 32, height: 32)
                                .overlay(
                                    Circle()
                                        .stroke(Color.primary, lineWidth: color == hex ? 3 : 0)
                                )
                                .onTapGesture {
                                    color = hex
                                }
                        }
                    }
                    .padding(.vertical, 8)
                }

                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("编辑规划")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        Task {
                            await updatePlan()
                        }
                    }
                    .disabled(name.isEmpty || isLoading)
                }
            }
        }
    }

    private func updatePlan() async {
        isLoading = true
        let request = UpdatePlanRequest(
            name: name,
            description: description.isEmpty ? nil : description,
            icon: icon,
            color: color,
            isArchived: nil
        )

        do {
            let updatedPlan = try await PlanService.shared.updatePlan(id: plan.id, request)
            onUpdate(updatedPlan)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

// MARK: - 添加任务视图
struct AddTaskView: View {
    @Environment(\.dismiss) var dismiss
    let planId: Int
    var parentId: Int? = nil

    @State private var title = ""
    @State private var description = ""
    @State private var priority: TaskPriority = .low
    @State private var dueDate: Date = Date()
    @State private var hasDueDate = false
    @State private var isLoading = false
    @State private var errorMessage: String?

    var onAdd: (PlanTask) -> Void

    var body: some View {
        NavigationView {
            Form {
                Section("任务信息") {
                    TextField("任务标题", text: $title)

                    TextField("描述（可选）", text: $description, axis: .vertical)
                        .lineLimit(3...5)
                }

                Section("设置") {
                    Picker("优先级", selection: $priority) {
                        ForEach(TaskPriority.allCases, id: \.rawValue) { p in
                            Text(p.title).tag(p)
                        }
                    }

                    Toggle("设置截止日期", isOn: $hasDueDate)

                    if hasDueDate {
                        DatePicker("截止日期", selection: $dueDate, displayedComponents: .date)
                    }
                }

                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle(parentId == nil ? "新建任务" : "新建子任务")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("创建") {
                        Task {
                            await saveTask()
                        }
                    }
                    .disabled(title.isEmpty || isLoading)
                }
            }
        }
    }

    private func saveTask() async {
        isLoading = true
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        let request = CreateTaskRequest(
            planId: planId,
            parentId: parentId,
            title: title,
            description: description.isEmpty ? nil : description,
            priority: priority.rawValue,
            dueDate: hasDueDate ? formatter.string(from: dueDate) : nil
        )

        do {
            let task = try await PlanService.shared.createTask(request)
            onAdd(task)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

// MARK: - 编辑任务视图
struct EditTaskView: View {
    @Environment(\.dismiss) var dismiss
    let task: PlanTask

    @State private var title: String
    @State private var description: String
    @State private var priority: TaskPriority
    @State private var dueDate: Date
    @State private var hasDueDate: Bool
    @State private var isLoading = false
    @State private var errorMessage: String?

    var onUpdate: (PlanTask) -> Void

    init(task: PlanTask, onUpdate: @escaping (PlanTask) -> Void) {
        self.task = task
        self.onUpdate = onUpdate
        _title = State(initialValue: task.title)
        _description = State(initialValue: task.description)
        _priority = State(initialValue: task.priorityLevel)

        // 解析截止日期
        if let dueDateStr = task.dueDate, !dueDateStr.isEmpty {
            // 尝试 ISO 8601 格式
            let isoFormatter = ISO8601DateFormatter()
            if let date = isoFormatter.date(from: dueDateStr) {
                _dueDate = State(initialValue: date)
                _hasDueDate = State(initialValue: true)
            } else {
                // 尝试简单日期格式
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd"
                if let date = formatter.date(from: dueDateStr) {
                    _dueDate = State(initialValue: date)
                    _hasDueDate = State(initialValue: true)
                } else {
                    _dueDate = State(initialValue: Date())
                    _hasDueDate = State(initialValue: false)
                }
            }
        } else {
            _dueDate = State(initialValue: Date())
            _hasDueDate = State(initialValue: false)
        }
    }

    var body: some View {
        NavigationView {
            Form {
                Section("任务信息") {
                    TextField("任务标题", text: $title)

                    TextField("描述（可选）", text: $description, axis: .vertical)
                        .lineLimit(3...5)
                }

                Section("设置") {
                    Picker("优先级", selection: $priority) {
                        ForEach(TaskPriority.allCases, id: \.rawValue) { p in
                            Text(p.title).tag(p)
                        }
                    }

                    Toggle("设置截止日期", isOn: $hasDueDate)

                    if hasDueDate {
                        DatePicker("截止日期", selection: $dueDate, displayedComponents: .date)
                    }
                }

                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("编辑任务")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        Task {
                            await updateTask()
                        }
                    }
                    .disabled(title.isEmpty || isLoading)
                }
            }
        }
    }

    private func updateTask() async {
        isLoading = true
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        let request = UpdateTaskRequest(
            title: title,
            description: description.isEmpty ? nil : description,
            priority: priority.rawValue,
            status: nil,
            dueDate: hasDueDate ? formatter.string(from: dueDate) : "",
            sortOrder: nil
        )

        do {
            let updatedTask = try await PlanService.shared.updateTask(id: task.id, request)
            onUpdate(updatedTask)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

// MARK: - Color 扩展
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

#Preview {
    PlanListView()
}
