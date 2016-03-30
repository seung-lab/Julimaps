"""
Multiple dispatch for meshwarp on Mesh object
"""
function meshwarp_mesh(mesh::Mesh)
  img = get_image(mesh)
  src_nodes, dst_nodes = get_globalized_nodes_h(mesh);
  src_nodes = src_nodes'
  dst_nodes = dst_nodes'
  offset = get_offset(mesh);
  node_dict = incidence_to_dict(mesh.edges')
  triangles = dict_to_triangles(node_dict)
  return @time ImageRegistration.meshwarp(img, src_nodes, dst_nodes, triangles, offset), mesh.index
end

"""
Multiple dispatch so Dodam doesn't have to type sooo much
"""
function render_montaged(wafer_no, section_no; render_full=true, render_review=true)
  render_montaged(wafer_no, section_no, wafer_no, section_no, render_full=render_full, render_review=render_review)
end

function render_montaged_review(fn)
  meshset = load(joinpath(MONTAGED_DIR, fn))
  render_montaged_review(meshset)
end

function render_montaged_review(meshset::MeshSet)
  try
    warps = pmap(meshwarp_mesh, meshset.meshes);
    imgs = [x[1][1] for x in warps];
    offsets = [x[1][2] for x in warps];
    indices = [x[2] for x in warps];
    # review images
    write_seams(meshset, imgs, offsets, indices)
  catch
    idx = (meshset.meshes[1].index[1:2]..., -2, -2)
    log_render_error(MONTAGED_DIR, idx, comment="")
  end
end

"""
`WRITE_SEAMS` - Write out overlays of montaged seams
""" 
function write_seams(meshset, imgs, offsets, indices)
    bbs = []
    for (img, offset) in zip(imgs, offsets)
        push!(bbs, BoundingBox(offset..., size(img)...))
    end
    overlap_tuples = find_overlaps(bbs)
    for (k, (i,j)) in enumerate(overlap_tuples)
      println("Writing seam ", k, " / ", length(overlap_tuples))
      path = get_review_path(indices[i], indices[j])
      try 
        img, fuse_offset = imfuse(imgs[i], offsets[i], imgs[j], offsets[j])
        bb = bbs[i] - bbs[j]
        img_cropped = imcrop(img, fuse_offset, bb)
        f = h5open(path, "w")
    	chunksize = min(50, min(size(img_cropped)...))
    	@time f["img", "chunk", (chunksize,chunksize)] = img_cropped
        f["offset"] = [bb.i, bb.j]
        f["scale"] = 1.0
        close(f)
      catch e
        idx = (indices[i], indices[j])
        log_render_error(MONTAGED_DIR, idx, e)
      end
    end
end

"""
Cycle through JLD files in montaged directory and render montage
"""
function render_montaged(waferA, secA, waferB, secB; render_full=true, render_review=true)
  indexA = montaged(waferA, secA)
  indexB = montaged(waferB, secB)
  for index in get_index_range(indexA, indexB)
    meshset = load(montaged(index))
    try
      new_fn = string(join(index[1:2], ","), "_montaged.h5")
      println("Rendering ", new_fn)
      warps = pmap(meshwarp_mesh, meshset.meshes);
      imgs = [x[1][1] for x in warps];
      offsets = [x[1][2] for x in warps];
      indices = [x[2] for x in warps];
      # review images
      if render_review
        write_seams(meshset, imgs, offsets, indices)
      end
      if render_full
        println(typeof(imgs))
        img, offset = merge_images(imgs, offsets)
        println("Writing ", new_fn)
        f = h5open(joinpath(MONTAGED_DIR, new_fn), "w")
    	chunksize = min(1000, min(size(img)...))
    	@time f["img", "chunk", (chunksize,chunksize)] = img
        close(f)
        update_offset(montaged(index), [0,0], size(img))
      end
    catch e
      log_render_error(MONTAGED_DIR, montaged(index), e)
    end
  end 
end

"""
Calculate prealignment transforms from first section through section_num
"""
function calculate_cumulative_tform(index)
  cumulative_tform = eye(3)
  if index != montaged(ROI_FIRST)
    index_pairs = get_sequential_index_pairs(montaged(ROI_FIRST), index)
    for (indexA, indexB) in index_pairs
      meshset = load(indexB, indexA)
      # reset cumulative tform if the mesh is fixed
      if is_fixed(meshset.meshes[2])
        println(meshset.meshes[2].index, ": fixed")
        cumulative_tform = eye(3)
      end
      # tform = affine_approximate(meshset)
      offset = get_offset(indexB)
      translation = [1 0 0; 0 1 0; offset[1] offset[2] 1]
      tform = regularized_solve(meshset, lambda=0.9)
      cumulative_tform = cumulative_tform*translation*tform
    end
  end
  return cumulative_tform
end

"""
Copy a section from one process step to the next
"""
function copy_section_through(index)
  println("copy_section_through INCOMPLETE")
  return
end

"""
Prealignment where offsets are global
"""
function render_prealigned(waferA, secA, waferB, secB; render_full=true, render_review=true)
  indexA = montaged(waferA, secA)
  indexB = montaged(waferB, secB)
  dir = PREALIGNED_DIR
  scale = 0.05
  s = [scale 0 0; 0 scale 0; 0 0 1]
  fixed = Dict()

  cumulative_tform = calculate_cumulative_tform(indexA)
  # cumulative_tform = eye(3)

  # return Dictionary of staged image to remove redundancy in loading
  function stage_image(mesh, cumulative_tform, tform)
    stage = Dict()
    stage["index"] = montaged(mesh.index)
    img = get_image(mesh)
    println("tform:\n", tform)
    if cumulative_tform*tform == eye(3)
      stage["img"], stage["offset"] = img, [0,0]
    else
      println("Warping ", get_index(mesh))
      @time stage["img"], stage["offset"] = imwarp(img, cumulative_tform*tform, [0,0])
    end
    println("Creating thumbnail for ", get_index(mesh))
    stage["thumb_fixed"], stage["thumb_offset_fixed"] = imwarp(img, s, [0,0])
    stage["thumb_moving"], stage["thumb_offset_moving"] = imwarp(img, tform*s, [0,0])
    stage["scale"] = scale
    return stage
  end

  function save_image(stage)
    new_fn = string(join(stage["index"][1:2], ","), "_prealigned.h5")
    update_offset(prealigned(stage["index"]), stage["offset"], size(stage["img"]))
    println("Writing image:\n\t", new_fn)
    # @time imwrite(stage["img"], joinpath(dir, fn))
    f = h5open(joinpath(dir, new_fn), "w")
    chunksize = min(1000, min(size(stage["img"])...))
    @time f["img", "chunk", (chunksize,chunksize)] = stage["img"]
    close(f)
  end

  index_pairs = get_sequential_index_pairs(indexA, indexB)
  for (k, (indexA, indexB)) in enumerate(index_pairs)
    println("\nRendering ", indexA, " & ", indexB)
    meshset = load(indexB, indexA)
    if k==1
      fixed = stage_image(meshset.meshes[2], cumulative_tform, eye(3))
    end
    offset = get_offset(indexB)
    translation = [1 0 0; 0 1 0; offset[1] offset[2] 1]
    tform = translation*regularized_solve(meshset, lambda=0.9)
    moving = stage_image(meshset.meshes[1], cumulative_tform, tform)
    
    # save full scale image
    if render_full
      save_image(moving)
    end

    if render_review
      # save thumbnail of fused images
      path = get_review_path(moving["index"], fixed["index"])
      O, O_bb = imfuse(fixed["thumb_fixed"], fixed["thumb_offset_fixed"], 
                            moving["thumb_moving"], moving["thumb_offset_moving"])
      f = h5open(path, "w")
      chunksize = min(1000, min(size(O)...))
      @time f["img", "chunk", (chunksize,chunksize)] = O
      f["offset"] = O_bb
      f["scale"] = scale
      f["tform"] = tform
      close(f)
      println("Writing thumb:\n\t", path)
    end

    # propagate for the next section
    fixed = moving
    cumulative_tform = cumulative_tform*tform
  end
end

"""
Render aligned images
"""
function render_aligned_review(waferA, secA, waferB, secB, start=1, finish=0)
  indexA = prealigned(waferA, secA)
  indexB = prealigned(waferB, secB)
  meshset = load(indexA, indexB)
  render_aligned_review(meshset, start, finish)
end

function render_aligned_review(meshset, start=1, finish=0)
  scale = 0.10
  s = [scale 0 0; 0 scale 0; 0 0 1]

  if start <= 0
    start = 1
  end
  if finish <= 0
    finish = length(meshset.matches)
  end
  images = Dict()
  BB = GLOBAL_BB
  
  # Check images dict for thumbnail, otherwise render it - just moving prealigned
  function retrieve_image(mesh)
    index = aligned(mesh.index)
    if !(index in keys(images))
      println("Making review for ", mesh.index)
      # @time (img, offset), _ = meshwarp_mesh(mesh)
      # GLOBAL_BB = BoundingBox(-4000,-4000,38000,38000)
      img = get_image(mesh)
      offset = get_offset(mesh)
      # @time img = rescopeimage(img, offset, BB)
      img, offset = imwarp(img, s, offset)
      images[index] = img, offset
    end
    return images[index]
  end

  for (k, match) in enumerate(meshset.matches[start:finish])
    src_index = match.src_index
    dst_index = match.dst_index

    src_mesh = meshset.meshes[find_mesh_index(meshset, src_index)]
    dst_mesh = meshset.meshes[find_mesh_index(meshset, dst_index)]

    src_img, src_offset = retrieve_image(src_mesh)
    dst_img, dst_offset = retrieve_image(dst_mesh)
    # offset = [BB.i, BB.j] * scale
    O, O_bb = imfuse(src_img, src_offset, dst_img, dst_offset)

    indexA = aligned(src_index)
    indexB = aligned(dst_index)

    path = get_review_path(indexB, indexA)
    println("Writing thumbnail:\n\t", path)
    f = h5open(path, "w")
    @time f["img", "chunk", (1000,1000)] = O
    f["offset"] = O_bb # same as offset
    f["scale"] = scale
    close(f)
  end
end

"""
Render aligned images
"""
function render_aligned(waferA, secA, waferB, secB, start=1, finish=0)
  indexA = prealigned(waferA, secA)
  indexB = prealigned(waferB, secB)
  meshset = load(indexA, indexB)
  render_aligned(meshset, start, finish)
end

function render_aligned(meshset, start=1, finish=0)
  scale = 0.10
  s = [scale 0 0; 0 scale 0; 0 0 1]

  if start <= 0
    start = 1
  end
  if finish <= 0
    finish = length(meshset.meshes)
  end
  images = Dict()

  for (k, mesh) in enumerate(meshset.meshes[start:finish])
    index = aligned(mesh.index)
    println("Warping ", mesh.index)
    @time (img, offset), _ = meshwarp_mesh(mesh)
    println("Writing ", get_name(index))
    f = h5open(get_path(index), "w")
    @time f["img", "chunk", (1000,1000)] = img
    close(f)
    # Log image offsets
    update_offset(index, offset, size(img))
    images[index] = imwarp(img, s) 
    # Rescope the image & save
    write_finished(index, img, offset, GLOBAL_BB)
  end

  for (k, match) in enumerate(meshset.matches)
    src_index = aligned(match.src_index)
    dst_index = aligned(match.dst_index)

    if start <= find_mesh_index(meshset, src_index) <= finish &&
          start <= find_mesh_index(meshset, dst_index) <= finish

      src_img, src_offset = retrieve_image(src_mesh)
      dst_img, dst_offset = retrieve_image(dst_mesh)
      O, O_bb = imfuse(src_img, src_offset, dst_img, dst_offset)

      path = get_review_path(dst_index, src_index)
      println("Writing thumbnail:\n\t", path)
      f = h5open(path, "w")
      @time f["img", "chunk", (1000,1000)] = O
      f["offset"] = O_bb # same as offset
      f["scale"] = scale
      close(f)
    end
  end
end

function render_finished(waferA, secA, waferB, secB)
  indexA = aligned(waferA, secA)
  indexB = aligned(waferB, secB)
  for index in get_index_range(indexA, indexB)
    img = get_image(index)
    offset = get_offset(index)
    write_finished(index, img, offset)
  end
end

function write_finished(index, img, offset, BB=GLOBAL_BB)
  println("Rescoping ", get_name(index))
  @time img = rescopeimage(img, offset, BB)
  index = finished(index)
  println("Writing ", get_name(index))
  f = h5open(get_path(index), "w")
  @time f["img", "chunk", (1000,1000)] = img
  f["offset"] = offset
  f["bb"] = [BB.i, BB.j, BB.w, BB.h]
  close(f)
end

"""
Write any render errors to a log file
"""
function log_render_error(dir, idx, comment="")
  ts = parse(Dates.format(now(), "yymmddHHMMSS"))
  path = joinpath(dir, "render_error_log.txt")
  new_row = [ts, idx, comment]'
  if !isfile(path)
    f = open(path, "w")
    close(f)
    log = new_row
  else  
    log = readdlm(path)
    log = vcat(log, new_row)
  end
  log = log[sortperm(log[:, 1]), :]
  println("Logging render error:\n", path)
  writedlm(path, log)
end
