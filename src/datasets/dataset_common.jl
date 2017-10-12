
# generates Janelia-type tilespec from the registry
function generate_tilespec_from_registry(index; dataset = "", stack = "", stack_type = "", parent_stack = "")
  	tileid = "$(index[1]),$(index[2])_$stack"
	tilespec = Dict{Symbol, Any}()
	tilespec[:tileId] = tileid
	tilespec[:z] = find_in_registry(index)
	tilespec[:width] = get_image_size(index)[2]
	tilespec[:height] = get_image_size(index)[1]
	tilespec[:minX] = get_offset(index)[2]
	tilespec[:minY] = get_offset(index)[1]
	# we need the meta field w
	tilespec[:meta] = Dict{Symbol, Any}()
	tilespec[:meta][:dataset] = dataset
	tilespec[:meta][:stack] = stack
	tilespec[:meta][:stack_type] = stack_type
	tilespec[:meta][:parent_stack] = parent_stack
	tilespec[:meta][:resolution] = (30,30,40)
	tilespec[:channels] = Dict{Symbol, Any}()
	tilespec[:channels][:nccnet] = Dict{Symbol, Any}()
	tilespec[:channels][:nccnet][:imageUrl] = "file://$(get_path(bucket = BUCKET_NEW, dataset = dataset, stack = stack, obj_name = "nccnet", tileid = tileid))"
	#tilespec[:render] = Dict{Symbol, Any}()
	#tilespec[:render][:transform] = "file://$(get_path(bucket = BUCKET_NEW, dataset = dataset, stack = stack, obj_name = "cumulative_tform", tileid = tileid))"
	tilespec[:mipmapLevels] = Dict{Symbol, Any}()
	tilespec[:mipmapLevels][Symbol(0)] = Dict{Symbol, Any}()
	tilespec[:mipmapLevels][Symbol(0)][:imageUrl] = "file://$(get_path(bucket = BUCKET_NEW, dataset = dataset, stack = stack, obj_name = "image", tileid = tileid))"
	#tilespec[:mipmapLevels][:0][:imageUrl] = "file://$BUCKET/$(get_path(dataset = dataset, stack = stack, tileid = tileid))"
	save(get_path(bucket = BUCKET_NEW, dataset = dataset, stack = stack, obj_name = "tilespec", tileid = tileid), tilespec)
end

function generate_stackspec(dataset = "", stack = "")
	stackspec = Dict{Symbol, Any}()
  	tileid = "$(index[1]),$(index[2])_$stack"
	tilespec = Dict{Symbol, Any}()
	tilespec[:tileId] = tileid
	tilespec[:z] = find_in_registry(index)
	tilespec[:width] = get_image_size(index)[2]
	tilespec[:height] = get_image_size(index)[1]
	tilespec[:minX] = get_offset(index)[2]
	tilespec[:minY] = get_offset(index)[1]
	# we need the meta field w
	tilespec[:meta] = Dict{Symbol, Any}()
	tilespec[:meta][:dataset] = dataset
	tilespec[:meta][:stack] = stack
	tilespec[:meta][:parent_stack] = parent_stack
	tilespec[:meta][:resolution] = (30,30,40)
	tilespec[:mipmapLevels] = Dict{Symbol, Any}()
	tilespec[:mipmapLevels][Symbol(0)] = Dict{Symbol, Any}()
	tilespec[:mipmapLevels][Symbol(0)][:imageUrl] = "file://$(get_path(bucket = BUCKET_NEW, dataset = dataset, stack = stack, tileid = tileid))"
	#tilespec[:mipmapLevels][:0][:imageUrl] = "file://$BUCKET/$(get_path(dataset = dataset, stack = stack, tileid = tileid))"
	save(get_path(bucket = BUCKET_NEW, dataset = dataset, stack = stack, obj_name = "tilespec", tileid = tileid), tilespec)
end

# EXAMPLE ENTRY FOR THINGS THAT MUST BE SPECIFIED IN dataset_*.jl
# global BUCKET = "/home/ubuntu/datasets" 	# if BUCKET is different for each computer, then use some if statements
#
# global DATASET = "zebrafish	"		# each DATASET lives under BUCKET, i.e. BUCKET/DATASET
#						# i.e. if there are two datasets named "zebrafish" and "piriform"
#						# zebrafish folders will exist as /home/ubuntu/datasets/zebrafish/0_overview, /home/ubuntu/datasets/zebrafish/1_premontaged...
#						# piriform folders will exist as /home/ubuntu/datasets/piriform/0_overview, /home/ubuntu/datasets/piriform/1_premontaged...
#
# global DATASET_RESOLUTION = [7,7,40] 	     	# dataset resolution in each dimension (i, j, k) or (y, x, z)
#
# global ROI_FIRST = (2,3,0,0)			# where the dataset starts - used for prealignment
# global ROI_LAST = (9,163,0,0)			# where the dataset ends

# gets the url of the image for the given tileid
function get_path(tileid::AbstractString, mipmap = 0; bucket::AbstractString = CUR_BUCKET, dataset::AbstractString = CUR_DATASET, stack::AbstractString = get_stack(tileid))
	  tilespec = load(get_path(; bucket = bucket, dataset = dataset, stack = stack, obj_name = "tilespec", tileid = tileid))
	  return get_path(tilespec, mipmap)
end

# gets the url of the image at tilespec and miplevel specified
function get_path(tilespec::Dict, mipmap = 0)
	return tilespec[:mipmapLevels][Symbol(mipmap)][:imageUrl];
end

# returns the path of the object from a tileid
function get_path(; bucket::AbstractString = CUR_BUCKET, dataset::AbstractString = CUR_DATASET, stack::AbstractString = "", obj_name::AbstractString = "", tileid::Union{AbstractString, Tuple{AbstractString, AbstractString}} = "")
  	subdir, ext = get_subdir(obj_name)
	# return the folder if the tileid is not given, suppressing the extenstion
	if tileid == ""
		return joinpath(bucket, dataset, stack, subdir)
	end
	if obj_name != ""
	  # singleton tile case
	  	if typeof(tileid) <: AbstractString
		return joinpath(bucket, dataset, stack, subdir, string(obj_name, "(", tileid, ")", ext))
	        else
	  # handling for meshset cases
		return joinpath(bucket, dataset, stack, subdir, string(obj_name, tileid, ext))
		end
	      else
		return joinpath(bucket, dataset, stack, subdir, string(tileid, ext))
	end
end

# catch-all for finding path for data types
function get_path(data)
	object_type = string(typeof(data))
	tileid = get_index(data)
	return get_path(; stack = nextstack(get_stack(typeof(tileid) <: AbstractString ? tileid : tileid[1])), obj_name = object_type, tileid = tileid)
	end
#=
# default get_name for objects
function get_name(object)
	if string(typeof(object)) == "MeshSet"
		firstindex = get_index(object.meshes[1]);
		lastindex = get_index(object.meshes[end]);
		if is_premontaged(firstindex) return "$(firstindex[1]),$(firstindex[2])_montaged";
		elseif is_montaged(firstindex) return "$(firstindex[1]),$(firstindex[2])_prealigned";
		else  return "$(firstindex[1]),$(firstindex[2])-$(lastindex[1]),$(lastindex[2])_aligned"; end
	else
	      #end hack
	index = get_index(object)
	if typeof(index) == FourTupleIndex 			return string(typeof(object), "(", index, ")")	
        elseif typeof(index) == Tuple{FourTupleIndex, FourTupleIndex} 	return string(typeof(object), index)	end
      end
	
end
=#
#=
function get_name(object_type::DataType, dataset::AbstractString, stack::AbstractString, tileid::AbstractString)
end
=#
#=
function get_name(index::FourTupleIndex)
    if is_overview(index)	    	return string(index[1], ",", index[2], "_overview")
    elseif is_premontaged(index)	return string(index)
    elseif is_montaged(index)		return string(index[1], ",", index[2], "_montaged")
    elseif is_prealigned(index)
      if is_subsection(index)		return string(index[1], ",", index[2], "_prealigned_", index[4])
      else 				return string(index[1], ",", index[2], "_prealigned") end
    elseif is_aligned(index)		return string(index[1], ",", index[2], "_aligned")
    elseif is_finished(index) 		return string(index[1], ",", index[2], "_finished")
    end
  end
=#
# used for loading - i.e. getting the name of the Mesh by calling get_name((2,3,1,4), Mesh) returns "Mesh((2,3,1,4))"
function get_name(object_type::Union{DataType, AbstractString}, index)	
  #=
	if object_type == "MeshSet" || string(object_type) == "MeshSet"
	  if typeof(index) == Tuple{AbstractString, AbstractString}
	    firsttile = index[1]
	    lasttile = index[2]
	      return string("MeshSet(", firsttile, lasttile ")")
	  elseif typeof(index) == AbstractString 
	    return string("MeshSet(", index, ")")
	end
	=#
	  #=
	  # hack for old names
	  if typeof(index) == Tuple{FourTupleIndex, FourTupleIndex}
		firstindex = index[1]
		lastindex = index[2]
		if is_premontaged(firstindex) return "$(firstindex[1]),$(firstindex[2])_montaged";
		elseif is_montaged(firstindex) return "$(firstindex[1]),$(firstindex[2])_prealigned";
		else  return "$(firstindex[1]),$(firstindex[2])-$(lastindex[1]),$(lastindex[2])_aligned"; end
	      else
		if is_montaged(index) return "$(index[1]),$(index[2])_montaged";
		elseif is_prealigned(index) return "$(index[1]),$(index[2])_prealigned"; end
	      end
	      end
	      #end hack
	      =#
  	# singleton case
	if typeof(index) == AbstractString 			return string(object_type, "(", index, ")")	
        elseif typeof(index) == Tuple{AbstractString, AbstractString} 	return string(object_type, index)	end
end
# used for saving - gets the canonical name of the object
function get_name(object)		
	  # hack for old names
	#if object == "MeshSet" || string(typeof(object)) == "MeshSet"
	if string(typeof(object)) == "MeshSet"
		firstindex = get_index(object.meshes[1]);
		lastindex = get_index(object.meshes[end]);
		if get_z(firstindex) == get_z(lastindex)
		  return "MeshSet($(nextstage(firstindex)))"
		else return "MeshSet($firstindex,$lastindex)"
		end
#=
		if is_premontaged(firstindex) return "$(firstindex[1]),$(firstindex[2])_montaged";
		elseif is_montaged(firstindex) return "$(firstindex[1]),$(firstindex[2])_prealigned";
		else  return "$(firstindex[1]),$(firstindex[2])-$(lastindex[1]),$(lastindex[2])_aligned"; end
		=#
	else
	      #end hack
	index = get_index(object)
	if typeof(index) == AbstractString 			return string(typeof(object), "(", index, ")")	
        elseif typeof(index) == Tuple{AbstractString, AbstractString} 	return string(typeof(object), index)	end
      end
end
#=
# gets the full directory of the index as if it were an image - e.g. .../1_premontaged
function get_dir_path(index::Union{FourTupleIndex, Tuple{FourTupleIndex, FourTupleIndex}})
  if typeof(index) != FourTupleIndex index = index[1] end
    if is_overview(index)		return OVERVIEW_DIR_PATH
    elseif is_premontaged(index) 	return PREMONTAGED_DIR_PATH
    elseif is_montaged(index) 		return MONTAGED_DIR_PATH
    elseif is_prealigned(index) 	return PREALIGNED_DIR_PATH
    elseif is_aligned(index) 		return ALIGNED_DIR_PATH
    elseif is_finished(index) 		return FINISHED_DIR_PATH	end
end
=#

# gets the full directory of the object based on get_index
function get_dir_path(object)
  index = get_index(object); if typeof(index) != FourTupleIndex index = index[1]	end
  return get_dir_path(index)
end

# gets the directory under the stack
function get_subdir(object)  			return get_subdir(typeof(object))	end
function get_subdir(object_type::DataType)	return get_subdir(string(object_type));	end

function get_subdir(string::AbstractString)
  if 	 contains(string, "Mesh")	return MESH_DIR, ".jls"
  elseif contains(string, "Match")      return MATCH_DIR, ".jls"
  elseif contains(string, "MeshSet")    return MESHSET_DIR, ".jls"
  elseif contains(string, "review")     return REVIEW_DIR, ".h5"
  elseif contains(string, "import")     return IMPORT_DIR, ".txt"
  elseif contains(string, "contrast_bias")     return CONTRAST_BIAS_DIR, ".h5"
  elseif contains(string, "contrast_stretch")     return CONTRAST_STRETCH_DIR, ".txt"
  elseif contains(string, "correspondence")     return CORRESPONDENCE_DIR, ".txt"
  elseif contains(string, "relative_transform")     return RELATIVE_TRANSFORM_DIR, ".txt"
  elseif contains(string, "cumulative_transform")     return CUMULATIVE_TRANSFORM_DIR, ".txt"
  elseif contains(string, "stats")     return STATS_DIR, ".json"
  elseif contains(string, "tilespec")     return TILESPEC_DIR, ".json"
  elseif contains(string, "params")     return "", ".json"
  elseif contains(string, "mask")     return MASK_DIR, ".txt"
  elseif contains(string, "outline")     return OUTLINE_DIR, ".png"
  elseif contains(string, "expunge")     return EXPUNGED_DIR, ".h5"
  elseif contains(string, "thumbnail")     return THUMBNAIL_DIR, ".h5"
    # support different channels by creating a folder if necessary
  elseif string != ""
    return string, ".h5"
    # catch-all case for the root of the stack
  else
    return "", ""
#  else return IMAGE_DIR, ".h5"
  end
end

# 
#=
# function get_path()
# methods: 
function get_path(index::FourTupleIndex, ext = ".h5")
  return joinpath(get_dir_path(index), string(get_name(index), ext))
end
=#

#=
function get_path(object_type::Union{DataType, AbstractString}, index)
  # hack to support singleton load for meshsets
  if (object_type == "stats" || contains(object_type, "MeshSet") || contains(string(object_type), "MeshSet")) && typeof(index) == FourTupleIndex
  return joinpath(get_dir_path(prevstage(index)), get_subdir(object_type)[1], string(get_name(object_type, index), get_subdir(object_type)[2]))
  end
  return joinpath(get_dir_path(index), get_subdir(object_type)[1], string(get_name(object_type, index), get_subdir(object_type)[2]))
end
function get_path(object)
  index = get_index(object); if typeof(index) != FourTupleIndex index = index[1]	end
  return joinpath(get_dir_path(index), get_subdir(object)[1], string(get_name(object), get_subdir(object)[2]))
end
=#
#=
function get_path(name::AbstractString)
    return get_path(parse_name(name))
end

function parse_index(s::AbstractString)
    m = Base.match(r"(\d+),(\d+),(\-\d+|\d+),(\-\d+|\d+)", s)
    return (parse(Int, m[1]), parse(Int, m[2]), parse(Int, m[3]), parse(Int, m[4]))
end

function parse_name(name::AbstractString)

    ret = (0, 0, 0, 0)
    # singleton tile
    m = Base.match(r"(\d+),(\d+),(\d+),(\d+)", name)
    if typeof(m) != Void
    ret = parse(Int, m[1]), parse(Int, m[2]), parse(Int, m[3]), parse(Int, m[4])
    end

    # overview image
    m = Base.match(r"(\d+),(\d+)_overview", name)
    if typeof(m) != Void
    ret = (parse(Int, m[1]), parse(Int, m[2]), -1, -1)
    end

    # montaged section
    m = Base.match(r"(\d+),(\d+)_montaged", name)
    if typeof(m) != Void
    ret = (parse(Int, m[1]), parse(Int, m[2]), -2, -2)
    end

    # prealigned section
    m = Base.match(r"(\d+),(\d+)_prealigned", name)
    if typeof(m) != Void
    ret = (parse(Int, m[1]), parse(Int, m[2]), -3, -3)
    end

    # prealigned_subsection
    m = match(r"(\d+),(\d+)_prealigned_(\d+)", name)
    if typeof(m) != Void
    ret = (parse(Int, m[1]), parse(Int, m[2]), parse(Int, m[3]), -3)
    end

    # aligned-section
    m = Base.match(r"(\d+),(\d+)_aligned", name)
    if typeof(m) != Void
    ret = (parse(Int, m[1]), parse(Int, m[2]),-4,-4)
    end

    return ret
end

function parse_registry(path::AbstractString)
    registry = Array{Any}(0, 0)
    if isfile(path)
        file = readdlm(path)
        registry = Array{Any}(size(file, 1), size(file, 2) + 1) # name, index, dx, dy
        for i in 1:size(registry, 1)
            index = parse_name(file[i, 1])
            registry[i, 1] = get_name(index)
            registry[i, 2] = index
            for j in 3:size(registry, 2)
                registry[i, j] = file[i, j-1]
            end
        end
      end
    return registry
end
=#
#=
global OVERVIEW_DIR = "0_overview"
global PREMONTAGED_DIR = "1_premontaged"
global MONTAGED_DIR = "2_montaged"
global PREALIGNED_DIR = "3_prealigned"
global ALIGNED_DIR = "4_aligned"
global FINISHED_DIR = "5_finished"
=#
global MESH_DIR = "mesh"
global MATCH_DIR = "match"
global MESHSET_DIR = "meshset"
global EXPUNGED_DIR = "expunged"
global REVIEW_DIR = "review"
global MASK_DIR = "mask"
global IMPORT_DIR = "import"
global STATS_DIR = "stats"
global TILESPEC_DIR = "tilespec"
global CONTRAST_BIAS_DIR = "contrast_bias"
global CONTRAST_STRETCH_DIR = "contrast_stretch"
global OUTLINE_DIR = "outline"
global THUMBNAIL_DIR = "thumbnail"
global CORRESPONDENCE_DIR = "correspondence"
global RELATIVE_TRANSFORM_DIR = "relative_transform"
global CUMULATIVE_TRANSFORM_DIR = "cumulative_transform"
global IMAGE_DIR = "image"

#=
global OVERVIEW_DIR_PATH = joinpath(BUCKET, DATASET, OVERVIEW_DIR)
global PREMONTAGED_DIR_PATH = joinpath(BUCKET, DATASET, PREMONTAGED_DIR)
global MONTAGED_DIR_PATH = joinpath(BUCKET, DATASET, MONTAGED_DIR)
global PREALIGNED_DIR_PATH = joinpath(BUCKET, DATASET, PREALIGNED_DIR)
global ALIGNED_DIR_PATH = joinpath(BUCKET, DATASET, ALIGNED_DIR)
global FINISHED_DIR_PATH = joinpath(BUCKET, DATASET, FINISHED_DIR)

global REGISTRY_FILENAME = "registry.txt"
#global REGISTRY_PREMONTAGED = parse_registry(joinpath(PREMONTAGED_DIR_PATH, REGISTRY_FILENAME))
#global REGISTRY_MONTAGED = parse_registry(joinpath(MONTAGED_DIR_PATH, REGISTRY_FILENAME))
global REGISTRY_PREALIGNED = parse_registry(joinpath(PREALIGNED_DIR_PATH, REGISTRY_FILENAME))
global REGISTRY_ALIGNED = parse_registry(joinpath(ALIGNED_DIR_PATH, REGISTRY_FILENAME))

function get_registry_path(index)
    if is_premontaged(index) 		return joinpath(PREMONTAGED_DIR_PATH, REGISTRY_FILENAME)
    elseif is_montaged(index) 		return joinpath(MONTAGED_DIR_PATH, REGISTRY_FILENAME)
    elseif is_prealigned(index) 	return joinpath(PREALIGNED_DIR_PATH, REGISTRY_FILENAME)
    elseif is_aligned(index) 		return joinpath(ALIGNED_DIR_PATH, REGISTRY_FILENAME)
    end
end
=#

function get_subdirs()
  # change the default
#  dirs = [ OVERVIEW_DIR, PREMONTAGED_DIR, MONTAGED_DIR, PREALIGNED_DIR, ALIGNED_DIR, FINISHED_DIR ]
  subdirs = [ MESH_DIR, MATCH_DIR, MESHSET_DIR, EXPUNGED_DIR, REVIEW_DIR, MASK_DIR, IMPORT_DIR, STATS_DIR, TILESPEC_DIR, CONTRAST_BIAS_DIR, CONTRAST_STRETCH_DIR, OUTLINE_DIR, THUMBNAIL_DIR, CORRESPONDENCE_DIR, RELATIVE_TRANSFORM_DIR, CUMULATIVE_TRANSFORM_DIR, IMAGE_DIR ]
  return subdirs  
end

function check_dirs(stack, bucket = CUR_BUCKET, dataset = CUR_DATASET)
    function setup_dir(dir)
        if !isdir(dir)
            println("Creating $dir")
            mkdir(dir)
        end
    end

    dataset_dir = joinpath(bucket, dataset)
    setup_dir(dataset_dir)
    stack_dir = joinpath(dataset_dir, stack)
    setup_dir(stack_dir)
    subdirs = get_subdirs()
    for sd in subdirs
      setup_dir(joinpath(stack_dir,sd))
    end

    # b_split = split(BUCKET,"/")
    # for k in 2:length(b_split)
    #    mkdir(joinpath(b_split[1:k]...))
    # end

    #=
    setup_dir(dataset_dir)
    for d in dirs
        path = joinpath(dataset_dir, d)
        setup_dir(path)
	for sd in subdirs
	  subpath = joinpath(path, sd)
       	  setup_dir(subpath)
	end
    end
    =#
end
#=
check_dirs()
=#
