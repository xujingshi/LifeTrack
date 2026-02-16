import SwiftUI

struct PlanListView: View {
    @State private var plans: [Plan] = []
    @State private var isLoading = false
    @State private var showAddPlan = false
    @State private var selectedStatus: Int? = nil
    @State private var errorMessage: String?

    var body: some View {
        NavigationView {
            Group {
                if isLoading && plans.isEmpty {
                    ProgressView("加载中...")
                } else if plans.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "list.bullet.clipboard")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        Text("暂无规划")
                            .foregroundColor(.gray)
                        Button("添加规划") {
                            showAddPlan = true
                        }
                    }
                } else {
                    List {
                        ForEach(plans) { plan in
                            PlanRowView(plan: plan, onStatusChange: { newStatus in
                                Task {
                                    await updateStatus(planId: plan.id, status: newStatus)
                                }
                            })
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    Task {
                                        await deletePlan(id: plan.id)
                                    }
                                } label: {
                                    Label("删除", systemImage: "trash")
                                }
                            }
                        }
                    }
                    .refreshable {
                        await loadPlans()
                    }
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
                        Button("全部") { selectedStatus = nil }
                        ForEach(PlanStatus.allCases, id: \.rawValue) { status in
                            Button(status.title) { selectedStatus = status.rawValue }
                        }
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                    }
                }
            }
            .sheet(isPresented: $showAddPlan) {
                AddPlanView { plan in
                    plans.insert(plan, at: 0)
                }
            }
            .task {
                await loadPlans()
            }
            .onChange(of: selectedStatus) { _ in
                Task {
                    await loadPlans()
                }
            }
        }
    }

    private func loadPlans() async {
        isLoading = true
        do {
            let result = try await PlanService.shared.getPlans(status: selectedStatus)
            plans = result.list
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

    private func updateStatus(planId: Int, status: Int) async {
        do {
            try await PlanService.shared.updateStatus(id: planId, status: status)
            await loadPlans()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - 规划行视图
struct PlanRowView: View {
    let plan: Plan
    let onStatusChange: (Int) -> Void

    var body: some View {
        HStack(spacing: 12) {
            // 状态图标
            Button {
                let nextStatus = (plan.status + 1) % 3
                onStatusChange(nextStatus)
            } label: {
                Image(systemName: plan.statusLevel.icon)
                    .font(.title2)
                    .foregroundColor(statusColor)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(plan.title)
                    .font(.headline)
                    .strikethrough(plan.status == 2)

                if let description = plan.description, !description.isEmpty {
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.gray)
                        .lineLimit(1)
                }

                HStack {
                    // 优先级
                    Text(plan.priorityLevel.title)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(priorityColor.opacity(0.2))
                        .foregroundColor(priorityColor)
                        .cornerRadius(4)

                    // 截止日期
                    if let dueDate = plan.dueDate {
                        Text(formatDate(dueDate))
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                }
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }

    private var statusColor: Color {
        switch plan.status {
        case 0: return .gray
        case 1: return .blue
        case 2: return .green
        default: return .gray
        }
    }

    private var priorityColor: Color {
        switch plan.priority {
        case 0: return .green
        case 1: return .orange
        case 2: return .red
        default: return .gray
        }
    }

    private func formatDate(_ dateString: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        if let date = formatter.date(from: dateString) {
            formatter.dateFormat = "MM/dd"
            return formatter.string(from: date)
        }
        return dateString
    }
}

// MARK: - 添加规划视图
struct AddPlanView: View {
    @Environment(\.dismiss) var dismiss
    @State private var title = ""
    @State private var description = ""
    @State private var priority: PlanPriority = .medium
    @State private var dueDate: Date = Date()
    @State private var hasDueDate = false
    @State private var isLoading = false
    @State private var errorMessage: String?

    var onAdd: (Plan) -> Void

    var body: some View {
        NavigationView {
            Form {
                Section("基本信息") {
                    TextField("标题", text: $title)
                    TextField("描述（可选）", text: $description, axis: .vertical)
                        .lineLimit(3...5)
                }

                Section("设置") {
                    Picker("优先级", selection: $priority) {
                        ForEach(PlanPriority.allCases, id: \.rawValue) { p in
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
            .navigationTitle("新建规划")
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
                            await savePlan()
                        }
                    }
                    .disabled(title.isEmpty || isLoading)
                }
            }
        }
    }

    private func savePlan() async {
        isLoading = true
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        let request = CreatePlanRequest(
            title: title,
            description: description.isEmpty ? nil : description,
            dueDate: hasDueDate ? formatter.string(from: dueDate) : nil,
            priority: priority.rawValue
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

#Preview {
    PlanListView()
}
