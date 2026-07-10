require 'xcodeproj'

project_path = '/Users/ibomb017/Desktop/bird_kingdom/frontend/BirdKingdom/BirdKingdom.xcodeproj'
project = Xcodeproj::Project.open(project_path)
target = project.targets.first

# Get the Resources group, explicitly create if not found
main_group = project.main_group.groups.find { |g| g.name == 'BirdKingdom' || g.path == 'BirdKingdom' }
if main_group
    res_group = main_group.groups.find { |g| g.path == 'Resources' || g.name == 'Resources' }
    unless res_group
        res_group = main_group.new_group('Resources', 'Resources')
    end

    # Paths
    model_path = 'BirdKingdom/Resources/model.tflite'
    labels_path = 'BirdKingdom/Resources/labels.txt'

    # Add references
    model_ref = res_group.files.find { |f| f.path == 'model.tflite' } || res_group.new_file('model.tflite')
    labels_ref = res_group.files.find { |f| f.path == 'labels.txt' } || res_group.new_file('labels.txt')
    
    # Add to Copy Bundle Resources
    phase = target.resources_build_phase
    phase.add_file_reference(model_ref, true)
    phase.add_file_reference(labels_ref, true)

    project.save
    puts "Done adding to PBXProj via Resource Group!"
else
    puts "Could not find BirdKingdom main group!"
end
