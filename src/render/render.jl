"""
Multiple dispatch for meshwarp on Mesh object
"""
function meshwarp_mesh(mesh::Mesh)
  img = get_image(mesh)
  src_nodes = hcat(get_nodes(mesh; globalized = true, use_post = false)...)'
  dst_nodes = hcat(get_nodes(mesh; globalized = true, use_post = true)...)'
  offset = get_offset(mesh);
  #=print("incidence_to_dict: ")
  @time node_dict = incidence_to_dict(mesh.edges') #'
  print("dict_to_triangles: ")
  @time triangles = dict_to_triangles(node_dict)=#
  node_dict = incidence_to_dict(mesh.edges') #
  triangles = dict_to_triangles(node_dict)
  return @time meshwarp(img, src_nodes, dst_nodes, triangles, offset), get_index(mesh)
end

"""
Reverts transform that went from index and returns the image at the index
"""
function meshwarp_revert(index::FourTupleIndex, img = get_image(nextstage(index)), interp = false)
  mesh = load("Mesh", index)
  src_nodes = hcat(get_nodes(mesh; globalized = true, use_post = false)...)'
  dst_nodes = hcat(get_nodes(mesh; globalized = true, use_post = true)...)'
  offset = get_offset(nextstage(index));
  #=print("incidence_to_dict: ")
  @time node_dict = incidence_to_dict(mesh.edges') #'
  print("dict_to_triangles: ")
  @time triangles = dict_to_triangles(node_dict)=#
  node_dict = incidence_to_dict(mesh.edges') #
  triangles = dict_to_triangles(node_dict)
  @time reverted_img, reverted_offset = meshwarp(img, dst_nodes, src_nodes, triangles, offset, interp)
  original_image_size = get_image_size(index)
  original_offset = get_offset(index)
  i_range = (1:original_image_size[1]) - reverted_offset[1] + original_offset[1] 
  j_range = (1:original_image_size[2]) - reverted_offset[2] + original_offset[2] 
  @inbounds return reverted_img[i_range, j_range]
end

"""
One-off code for CREMI
"""
function segmentation_revert(fn, savepath)
	segs = h5read(fn, "main")
	#cutout_range_i = 401:2900
	#cutout_range_j = 201:2700
	cutout_range_i = 651:2650
	cutout_range_j = 451:2450

	segs_reverted = zeros(UInt32, 1250, 1250, 125)
	for i in 1:125
	  	sec_num = i + 37
		img = zeros(UInt32, get_image_size(aligned(1,sec_num))...)
		offset = get_offset(aligned(1,sec_num))
		img[cutout_range_i - offset[1] + 1, cutout_range_j - offset[2] + 1] = segs[:,:,i]
		img_reverted = meshwarp_revert(prealigned(1,sec_num), img)
		segs_reverted[:,:,i] = img_reverted[912:2161, 912:2161]
	end
		f = h5open(savepath, "w"); @time f["main"] = segs_reverted; 
		close(f)
	return segs_reverted

end


"""
Applies mask associated with the image and writes to finished
"""
function apply_mask(index::FourTupleIndex)
	img = get_image(index).s
	mask = load("mask", index)
	fillpoly!(img, Array{Int64,1}(mask[:, 2]), Array{Int64,1}(mask[:, 1]), zero(eltype(img)); reverse = true);
	save(get_path(finished(index)), img);
	return img
end

function render(ms::MeshSet; review=false)
  if is_montaged(ms)
    if review
      render_montaged(ms, render_full=false, render_review=true, flagged_only=true)
    else
      render_montaged(ms, render_full=true, render_review=false, flagged_only=true)
    end
  elseif is_prealigned(ms)
    if review
      render_prealigned_review(ms)
    else
      render_prealigned_full(ms)
    end
  elseif is_aligned(ms)
    if review
      render_aligned_review(ms)
    else
      render_aligned(ms)
    end
  end
end

# todo make universal cleaner 
function render(index::FourTupleIndex; render_full=true)
  if is_montaged(index)
    ms = load(MeshSet, index);
    render_montaged(ms, render_full=true, render_review=false, flagged_only=true)
  end
  if is_prealigned(index)
      render_prealigned_full(index)
    end

  if is_aligned(index)
  mesh = load(Mesh, prevstage(index));
  if mesh == nothing return nothing end;
    new_fn = get_name(index)
    println("Rendering ", new_fn)
    warp = meshwarp_mesh(mesh);
    img = warp[1][1];
    offset = warp[1][2];

#      img, offset = merge_images(imgs, offsets)
      println("Writing ", new_fn)
      f = h5open(get_path(index), "w")
      chunksize = min(1000, min(size(img)...))
      @time f["img", "chunk", (chunksize,chunksize)] = img
        f["dtype"] = string(typeof(img[1]))
        f["offset"] = offset
        f["size"] = [size(img)...]
      close(f)
      update_registry(index; offset = offset, image_size = size(img))
    end
end

"""
Multiple dispatch so Dodam doesn't have to type sooo much
"""
function render_montaged(index::FourTupleIndex; render_full=true, render_review=true)
  meshset = load("MeshSet", index)
  render_montaged(meshset; render_full=render_full, render_review=render_review)
end

function render_montaged(meshset::MeshSet; render_full=true, render_review=false, flagged_only=true)
  assert(is_premontaged(meshset.meshes[1].index))
  crop = [0,0]
  thumbnail_scale = 0.02
  render_params = meshset.properties[:params][:render]
  if haskey(render_params, "crop")
    crop = render_params["crop"]
  end
  if haskey(render_params, :thumbnail_scale)
    thumbnail_scale = render_params[:thumbnail_scale]
  end
  index = montaged(meshset.meshes[1].index)
  if is_flagged(meshset) 
    println("The meshset has a flag. Continuing anyway....")
  end

  # try
    new_fn = get_name(index)
    println("Rendering ", new_fn)
    warps = map(meshwarp_mesh, meshset.meshes);
    imgs = [x[1][1] for x in warps];
    offsets = [x[1][2] for x in warps];
    indices = [x[2] for x in warps];

    indices_i = unique([ind[3] for ind in indices])
    indices_j = unique([ind[4] for ind in indices])
    indices_maxs_i = zeros(Int64, maximum(indices_i))
    indices_mins_i = fill(100, maximum(indices_i))
    indices_maxs_j = zeros(Int64, maximum(indices_j))
    indices_mins_j = fill(100, maximum(indices_j))
    for ind in indices
	    i = ind[3]; j = ind[4];
	    if indices_maxs_i[i] < j indices_maxs_i[i] = j end
	    if indices_mins_i[i] > j indices_mins_i[i] = j end
	    if indices_maxs_j[j] < i indices_maxs_j[j] = i end
	    if indices_mins_j[j] > i indices_mins_j[j] = i end
    end

    if |((crop .> [0,0])...)
      x, y = crop
      for k in 1:length(imgs)
#	i = indices[k][3]; j = indices[k][4];
       #= # imgs[k] = imcrop(imgs[k], offsets[k] imgs[k][x:(end-x+1), y:(end-y+1)]
        #imgs[k] = imgs[k][x:(end-x+1), y:(end-y+1)]
	i = indices[k][3]; j = indices[k][4];
	iend, jend = size(imgs[k])
	if indices_maxs_i[i] == j || indices_mins_i[i] == j || indices_maxs_j[j] == i || indices_mins_j[j] == i
        imgs[k] = imgs[k][x:(end-x+1), y:(end-y+1)]
        #imgs[k] = imgs[k][x:(end-x+1), y:(end-y+1)] + 150
	else
        imgs[k] = imgs[k][x:(end-x+250+1), y:(end-y+250+1)]
	end=#
#=	
	if i != indices_mins_j[j] && j != indices_mins_i[i] && i != indices_maxs_j[j] && j != indices_maxs_i[i] 
        imgs[k] = imgs[k][x-299:(end-x+299+1), y-299:(end-y+299+1)]
	offsets[k] = offsets[k] + crop - [299,299]
	else
		println("$i,$j")
        imgs[k] = imgs[k][x:(end-x+1+150), y:(end-y+1+150)]
        offsets[k] = offsets[k] + crop
	end
	=#
        imgs[k] = imgs[k][x:(end-x+1), y:(end-y+1)]
        offsets[k] = offsets[k] + crop
      end
    end

    # review images
    if render_review
      write_seams(meshset, imgs, offsets, indices, flagged_only)
    end
    if render_full
      img, offset = merge_images(imgs, offsets)
	
      #img_size = get_image_size(index);	
      #println("reg img_size: $img_size")
      #println("ren img_size: $(size(img))")
      #img = img[1:img_size[1], 1:img_size[2]];

      println("Writing ", new_fn)
      f = h5open(get_path(index), "w")
      chunksize = min(1000, min(size(img)...))
      @time f["img", "chunk", (chunksize,chunksize)] = img
      close(f)
      println("Creating thumbnail for $index @ $(thumbnail_scale)x")
      thumbnail, _ = imscale(img, thumbnail_scale)
      write_thumbnail(thumbnail, index, thumbnail_scale)
      update_registry(index; offset = [0,0], image_size = size(img))
    end
  # catch e
  #   println(e)
  #   log_error(index; comment=e)
  # end

end

function calculate_relative_transforms(firstindex::FourTupleIndex, lastindex::FourTupleIndex)
  assert(is_montaged(firstindex) && is_montaged(lastindex))
  for index in get_index_range(firstindex, lastindex)
    ms = load(MeshSet, prealigned(index))
    offset = get_offset(index)
    rotation = make_rotation_matrix_from_index(index)
    translation = make_translation_matrix(offset)
    tform = rotation*regularized_solve(ms)*translation
    println("Writing relative tform for $index")
    path = get_path("relative_transform", index)
    writedlm(path, tform)
  end
end

function compile_cumulative_transforms(firstindex::FourTupleIndex, lastindex::FourTupleIndex)
  assert(is_montaged(firstindex) && is_montaged(lastindex))
  cumulative_tform = eye(3)
  for index in get_index_range(firstindex, lastindex)
    if index != firstindex
      tform = load("relative_transform", index)
      cumulative_tform = tform*cumulative_tform
      cumulative_tform[:,3] = [0, 0, 1]
    end
    println("Writing cumulative tform for $index")
    path = get_path("cumulative_transform", index)
    writedlm(path, cumulative_tform)
  end
end

function render_prealigned_full(index::FourTupleIndex; thumbnail_scale=get_params(prevstage(index))[:render][:thumbnail_scale], overview=false, make_dense = true)
  index = montaged(index);
  img = load(index)
  scale = make_scale_matrix(1.0)
  if overview
    scale = make_scale_matrix(0.25)
  end
  tform = load("cumulative_transform", index)
  println("Warping image")
  @time warped, offset = imwarp(img, tform*scale, [0,0]; parallel = true)
  index = prealigned(index)

  if make_dense
	i_min, i_max = 1, size(warped, 1)
	j_min, j_max = 1, size(warped, 2)
  #	mins = get_offset(index) + [1,1] - offset
  #	maxs = get_image_size(index) + mins - [1,1]

	while (sum(slice(warped, i_min, 1:size(warped,2))) == 0); i_min += 1; end
	while (sum(slice(warped, i_max, 1:size(warped,2))) == 0); i_max -= 1; end
	while (sum(slice(warped, 1:size(warped,1), j_min)) == 0); j_min += 1; end
	while (sum(slice(warped, 1:size(warped,1), j_max)) == 0); j_max -= 1; end
#	i_min = mins[1]
#	j_min = mins[2]
#	i_max = maxs[1]
#	j_max = maxs[2]

	offset = offset - [1,1] + [i_min, j_min]
	towrite = Array(slice(warped, i_min:i_max, j_min:j_max))
      else
	towrite = warped;
  end

  update_registry(index, offset=offset, image_size=size(towrite))
  path = get_path(index)
  println("Writing full image:\n ", path)
  f = h5open(path, "w")
  chunksize = min(1000, min(size(towrite)...))
  #@time f["img", "chunk", (chunksize,chunksize)] = towrite
  @time f["img", "chunk", (chunksize, chunksize)] = (typeof(towrite) <: SharedArray ? towrite.s : towrite); close(f)
  println("Creating thumbnail for $index @ $(thumbnail_scale)x")
  thumbnail, _ = imscale(towrite, thumbnail_scale)
  write_thumbnail(thumbnail, index, thumbnail_scale)
  warped = 0;
  warped = 0;
  towrite = 0;
  towrite = 0;
  @everywhere gc();
end

function render_prealigned_review(src_index::FourTupleIndex, dst_index::FourTupleIndex, src_img, dst_img, 
                cumulative_tform, tform)
  review_scale = 0.02
  render_params = get_params(src_index)[:render]
  if haskey(render_params, "review_scale")
    review_scale = render_params["review_scale"]
  end
  s = make_scale_matrix(review_scale)

  dst_offset = [0,0]
  if is_aligned(dst_index)
    dst_offset = get_offset(dst_index)
    println("dst image is aligned, so translate:\t$dst_offset")
  end
  println("Warping prealigned review image... 1/2")
  src_thumb, src_thumb_offset = imwarp(src_img, tform*s, [0,0])
  println("Warping prealigned review image... 2/2")
  dst_thumb, dst_thumb_offset = imwarp(dst_img, s, dst_offset)
  path = get_path("review", (src_index, dst_index))
  write_review_image(path, src_thumb, src_thumb_offset, dst_thumb, dst_thumb_offset, review_scale, tform)

  # println("Warping aligned review image... 1/2")
  # src_thumb, src_thumb_offset = imwarp(src_img, tform*cumulative_tform*s, [0,0])
  # println("Warping aligned review image... 2/2")
  # dst_thumb, dst_thumb_offset = imwarp(dst_img, cumulative_tform*s, [dst_offset])
  # aligned_path = get_path("review", (src_index, dst_index))
  # write_review_image(aligned_path, src_thumb, src_thumb_offset, dst_thumb, dst_thumb_offset, scale, tform*cumulative_tform)
end

function render_prealigned_review(ms::MeshSet)
  src_index = get_index(ms.meshes[1])
  dst_index = get_index(ms.meshes[2])
  src_offset = get_offset(src_index)
  rotation = make_rotation_matrix_from_index(src_index)
  translation = make_translation_matrix(src_offset)
  #translation = make_translation_matrix(src_offset)
  tform = rotation*rigid_solve(ms)*translation
  println("Writing relative tform for $src_index")
  path = get_path("relative_transform", src_index)
  writedlm(path, tform)
  render_prealigned_review(src_index, dst_index, get_image(src_index), 
      get_image(dst_index), eye(3), tform)
end

function render_prematch_review(index::FourTupleIndex)
  src_index = index
  dst_index = get_preceding(index)
  src_offset = get_offset(src_index)
  rotation = make_rotation_matrix_from_index(src_index)
  translation = make_translation_matrix(src_offset)
  tform = rotation*translation
  # println("Writing relative tform for $src_index")
  # path = get_path("relative_transform", src_index)
  # writedlm(path, tform)
  # tform = load("relative_transform", src_index)
  render_prealigned_review(src_index, dst_index, get_image(src_index), 
      get_image(dst_index), eye(3), tform)
end

function write_review_image(path, src_img, src_offset, dst_img, dst_offset, scale, tform)
  O, O_bb = imfuse(dst_img, dst_offset, src_img, src_offset) # dst - red, src - green
  println("Writing review image:\n ", path)
  f = h5open(path, "w")
  chunksize = min(1000, min(size(O)...))
  @time f["img", "chunk", (chunksize,chunksize)] = O
  f["offset"] = O_bb
  f["scale"] = scale
  f["tform"] = tform
  close(f)
end

"""
Check images dict for thumbnail, otherwise render it - just moving prealigned
"""
function retrieve_image(images, index; tform=eye(3))
  if !(index in keys(images))
    println("Making review for ", index)
    img = get_image(index)
    offset = get_offset(index)
    img, offset = imwarp(img, tform, offset)
    images[index] = img, offset
  end
  return images[index]
end

"""
Render aligned images
"""
function render_aligned_review(firstindex::FourTupleIndex, lastindex::FourTupleIndex, start=1, finish=0; scale=0.05)
  firstindex, lastindex = prealigned(firstindex), prealigned(lastindex)
  meshset = load("MeshSet",(firstindex, lastindex))
  render_aligned_review(meshset, start, finish, scale=scale)
end

function render_aligned_review(meshset, start=1, finish=length(meshset.matches); images=Dict(), scale=0.05)
  s = make_scale_matrix(scale)

  for (k, match) in enumerate(meshset.matches[start:finish])
    src_index = get_src_index(match)
    dst_index = get_dst_index(match)

    src_img, src_offset = retrieve_image(images, src_index; tform=s)
    dst_img, dst_offset = retrieve_image(images, dst_index; tform=s)
    path = get_path("review", (src_index, dst_index))
    write_review_image(path, src_img, src_offset, dst_img, dst_offset, scale, s)
  end
end

@fastmath @inbounds function render_aligned(meshset::MeshSet, start=1, finish=length(meshset.meshes))
  thumbnail_scale = 0.02
  render_params = meshset.properties[:params][:render]
  if haskey(render_params, :thumbnail_scale)
    thumbnail_scale = render_params[:thumbnail_scale]
  end
  sort!(meshset.meshes; by=get_index)
  subsection_imgs = []
  subsection_offsets = []
  for (k, mesh) in enumerate(meshset.meshes)
    if start <= k <= finish
      index = get_index(mesh)
      println("Warping ", index)
      @time (img, offset), _ = meshwarp_mesh(mesh)
      if is_subsection(index)
        println("$index is a subsection")
        push!(subsection_imgs, img)
        push!(subsection_offsets, offset)
      end
      # determine if subsections should be merged 
      is_last_subsection = true
      if k != length(meshset.meshes)
        next_index = get_index(meshset.meshes[k+1])
        if prealigned(index) == prealigned(next_index)
          is_last_subsection = false
          println("Wait to merge...")
        end
      end
      if length(subsection_imgs) > 1 && is_last_subsection
        println("Merge subsections")
        img, offset = merge_images(subsection_imgs, subsection_offsets)
        subsection_imgs = []
        subsection_offsets = []
      end
      # render if subsections have been merged or is not a split section
      if is_last_subsection || !is_subsection(index)
        println("Writing ", get_name(aligned(index)))
        f = h5open(get_path(aligned(index)), "w")
        chunksize = min(1000, min(size(img)...))
        @time f["img", "chunk", (chunksize, chunksize)] = img
        f["dtype"] = string(typeof(img[1]))
        f["offset"] = offset
        f["size"] = [size(img)...]
        close(f)
        println("Creating thumbnail for $index @ $(thumbnail_scale)x")
        thumbnail, _ = imscale(img, thumbnail_scale)
        write_thumbnail(thumbnail, index, thumbnail_scale)
        # Log image offsets
        update_registry(aligned(index); offset = offset, image_size = size(img))
      end
    end
  end
end

function write_thumbnail(index::FourTupleIndex; scale=0.02)
  println("Creating thumbnail image for $index @ $(scale)x")
  img = sdata(get_image(index, scale))
  write_thumbnail(img, index, scale)
end

function write_thumbnail(img, index::FourTupleIndex, scale::Float64)
  println("Writing thumbnail image for $index @ $(scale)x")
  path = get_path("thumbnail", index)
  f = h5open(path, "w")
  chunksize = min(100, min(size(img)...))
  @time f["img", "chunk", (chunksize, chunksize)] = img
  f["scale"] = scale
  close(f)
end

function write_thumbnails(firstindex::FourTupleIndex, lastindex::FourTupleIndex; scale=0.02)
  for index in get_index_range(firstindex, lastindex)
    write_thumbnail(index, scale=scale)
  end
end

function crop(index::FourTupleIndex)
  mask = load("mask", index)
  scale = h5read(get_path("thumbnail", index), "scale")
  img = load()
end

function split_prealigned(index::FourTupleIndex)
  mask_path = get_mask_path(index)
  if isfile(mask_path)
    println("Splitting $index with mask")
    mask = load_mask(mask_path)
    img = get_image(index)
    subimgs = segment_by_mask(img, mask)
    offset = get_offset(index)
    for (i, subimg) in subimgs
      n = length(subimgs)
      subindex = subsection(index, i)
      path = get_path(subindex)
      println("Saving subsection $subindex: $i / $n")
      f = h5open(path, "w")
      chunksize = min(1000, min(size(subimg)...))
      @time f["img", "chunk", (chunksize,chunksize)] = subimg
      f["dtype"] = string(typeof(subimg[1]))
      f["offset"] = offset
      f["size"] = [size(subimg)...]
      close(f)
      # Log image offsets
      update_registry(subindex, offset = offset, image_size = size(subimg))
    end
  end
end

function split_prealigned(firstindex::FourTupleIndex, lastindex::FourTupleIndex)
  for index in get_index_range(firstindex, lastindex)
    mask_path = get_mask_path(index)
    if isfile(mask_path)
      split_prealigned(index)
    end
  end
end

# """
# Calculate prealignment transforms from first section through section_num

# Notes on transform composition:
# * Matrix operations happen from right to left, so repeat the orders of tform
#   calculations.
#     1. previous transforms: cumulative_tform
#     2. monoblock_match: translation
#     3. montage to montage matching: tform

#     tform * translation * cumulative_tform

#   * Be aware that aligned images are already positioned in global space, but
#     they are not *rescoped* to it. So the
#     aligned image offset needs to be accounted for as an additional translation.
#     If the image is fixed, it's assumed to be an aligned image, so we pull its
#     offset, and calculate the additional translation.
# """
# function prepare_prealignment(index::FourTupleIndex, startindex=montaged(ROI_FIRST))
#   src_index = montaged(index)
#   dst_index = get_preceding(src_index)

#   cumulative_tform = eye(3)
#   tform = eye(3)
#   for index in get_index_range(startindex, src_index)[2:end]
#     cumulative_tform = tform*cumulative_tform
#     src_index = index
#     dst_index = get_preceding(src_index)
#     meshset = load("MeshSet",(src_index, dst_index))
#     dst_index = get_index(meshset.meshes[2])
#     src_offset = get_offset(src_index)
#     translation = make_translation_matrix(src_offset)
#     rotation = make_rotation_matrix_from_index(src_index)
#     if is_fixed(meshset.meshes[2])
#       println("FIXED - currently doesn't support rotation")
#       cumulative_tform = eye(3)
#       dst_offset = get_offset(dst_index)
#       translation = make_translation_matrix(dst_offset)*translation
#     end
#     tform = rotation*regularized_solve(meshset)*translation
#   end
#   return src_index, dst_index, cumulative_tform, tform
# end

# function render_prealigned(index::FourTupleIndex; render_full=false, render_review=true, startindex=montaged(ROI_FIRST))
#   src_index, dst_index, cumulative_tform, tform = prepare_prealignment(index, startindex)
#   render_prealigned(src_index, dst_index, cumulative_tform, tform; 
#                           render_full=render_full, render_review=render_review)
# end

# function render_prealigned(src_index::FourTupleIndex, dst_index::FourTupleIndex, cumulative_tform, 
#                                   tform; render_full=false, render_review=true)
#   println("Loading images for rendering... 1/2")
#   src_img = get_image(src_index)
#   println("Loading images for rendering... 2/2")
#   dst_img = get_image(dst_index)
#   render_prealigned(src_index, dst_index, src_img, dst_img, cumulative_tform, 
#                     tform; render_full=render_full, render_review=render_review)
# end

# function render_prealigned(firstindex::FourTupleIndex, lastindex::FourTupleIndex; 
#                                         render_full=true, render_review=false, startindex=montaged(ROI_FIRST), align=false)
#   startindex = montaged(startindex)
#   dst_img = nothing
#   for index in get_index_range(montaged(firstindex), montaged(lastindex))
#     src_index, dst_index, cumulative_tform, tform = prepare_prealignment(index, startindex)
#     println("Loading src_image for rendering")
#     src_img = get_image(src_index)
#     if render_full && montaged(index) == montaged(startindex)
#       render_prealigned(src_index, dst_index, src_img, [], eye(3), 
#                       eye(3); render_full=true, render_review=false)
#     else
#       if dst_img == nothing
#         println("Loading dst_image for rendering")
#         dst_img = get_image(dst_index)
#       end
#       render_prealigned(src_index, dst_index, src_img, dst_img, cumulative_tform, 
#                       tform; render_full=render_full, render_review=render_review)

#       println(index, " ", firstindex, " ", align && montaged(index) > montaged(firstindex))
#       if align && montaged(index) > montaged(firstindex)
#         println("Aligning meshes between $dst_index, $src_index")
#         reload_registry(prealigned(src_index))
#         ms = MeshSet(prealigned(dst_index), prealigned(src_index); solve=false, fix_first=(dst_index==startindex))
#         render_aligned_review(ms)
#       end
#     end
#     println("Swapping src_image to dst_image")
#     dst_img = copy(src_img)
#   end
