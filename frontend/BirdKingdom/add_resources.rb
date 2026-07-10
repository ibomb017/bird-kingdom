require 'xcodeproj'

project_path = '/Users/ibomb017/Desktop/bird_kingdom/frontend/BirdKingdom/BirdKingdom.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# 找到主 Target
target = project.targets.first

# 找到或创建 Resources Group
main_group = project.main_group.groups.find { |g| g.name == 'BirdKingdom' || g.path == 'BirdKingdom' }
resources_group = main_group.groups.find { |g| g.name == 'Resources' } || main_group.new_group('Resources', 'Resources')

# 文件路径
model_path = '/Users/ibomb017/Desktop/bird_kingdom/frontend/BirdKingdom/BirdKingdom/Resources/model.tflite'
labels_path = '/Users/ibomb017/Desktop/bird_kingdom/frontend/BirdKingdom/BirdKingdom/Resources/labels.txt'

# 检查文件是否已存在于 Group
model_ref = resources_group.files.find { |f| f.path == 'model.tflite' }
labels_ref = resources_group.files.find { |f| f.path == 'labels.txt' }

# 添加到 Group (如果是新建)
model_ref ||= resources_group.new_reference(model_path)
labels_ref ||= resources_group.new_reference(labels_path)

# 获取 Copy Bundle Resources Phase
resources_build_phase = target.resources_build_phase

# 判断这两个文件是否已经在 Build Phase 中
unless resources_build_phase.files.any? { |f| f.file_ref == model_ref }
  resources_build_phase.add_file_reference(model_ref)
  puts "✅ 添加 model.tflite 到项目"
end

unless resources_build_phase.files.any? { |f| f.file_ref == labels_ref }
  resources_build_phase.add_file_reference(labels_ref)
  puts "✅ 添加 labels.txt 到项目"
end

project.save
puts "🎉 Xcode 资源更新完毕！"
