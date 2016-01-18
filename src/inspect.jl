function show_blockmatch(match, ind, params)
  src_patch, src_pt, dst_patch, dst_pt, xc, offset = get_correspondence_patches(match, ind)
  block_r = params["block_r"]
  search_r = params["search_r"]
  N=size(xc, 1)
  M=size(xc, 2)
  surf([i for i=1:N, j=1:M], [j for i=1:N, j=1:M], xc, cmap=get_cmap("hot"), 
                          rstride=10, cstride=10, linewidth=0, antialiased=false)
  xc_image = xcorr2Image(xc)
  xc_image = padimage(xc_image, block_r, block_r, block_r, block_r, 1)
  hot = create_hot_colormap()
  xc_color = apply_colormap(xc_image, hot)
  xc = padimage(xc', block_r, block_r, block_r, block_r, 1)
  fused_img, _ = imfuse(dst_patch, [0,0], src_patch, offset)

  src = convert(Array{UInt32,2}, src_patch).<< 8
  dst = convert(Array{UInt32,2}, dst_patch).<< 16

  cgrid = canvasgrid(2,2; pad=10)
  opts = Dict(:pixelspacing => [1,1])

  imgc, img2 = view(cgrid[1,1], src; opts...)
  imgc, img2 = view(cgrid[2,1], dst; opts...)
  imgc, img2 = view(cgrid[2,2], fused_img; opts...)
  imgc, img2 = view(cgrid[1,2], xc_color'; opts...)
  c = canvas(imgc)
  win = Tk.toplevel(c)
  return win
end

"""
Remove points displayed on ImageView with right-click
"""
function edit_matches(imgc, img2, matches, vectors, params)
    e = Condition()

    break_review = false
    indices_to_remove = Array{Integer,1}()
    lines = Void
    original_lines = Void
    for annotation in values(imgc.annotations)
      if :lines in fieldnames(annotation.data)
        lines = annotation.data.lines
        original_lines = copy(lines)
      end
    end
    mask = ones(Bool, size(original_lines,2))

    c = canvas(imgc)
    win = Tk.toplevel(c)
    bind(c, "<Button-3>", (c, x, y)->inspect_match(parse(Int, x), parse(Int, y)))
    bind(c, "<Control-Button-3>", (c, x, y)->remove_match(parse(Int, x), parse(Int, y)))
    bind(win, "<Delete>", path->path)
    bind(win, "<Escape>", path->exit_loop())
    bind(win, "<Destroy>", path->end_edit())
    bind(win, "<Return>", path->end_edit())
    bind(win, "z", path->end_edit())

    inspect_window = Void
    inspected_index = Void
    inspected_index_removed = true

    function remove_match(x, y)
        xu,yu = Graphics.device_to_user(Graphics.getgc(imgc.c), x, y)
        xi, yi = floor(Integer, 1+xu), floor(Integer, 1+yu)
        # println(xi, ", ", yi)
        limit = (img2.zoombb.xmax - img2.zoombb.xmin) * 0.0125 # 100/8000
        annidx = find_idx_of_nearest_pt(lines[1:2,:], [xi, yi], limit)
        if annidx > 0
            pt = lines[1:2,annidx]
            idx = find_pt_idx(original_lines[1:2,:], pt)
            println(idx, ": ", original_lines[1:2, idx])
            mask[idx] = false
            update_annotations(imgc, img2, original_lines, mask)
            push!(indices_to_remove, idx)
        end
    end

    function inspect_match(x, y)
        xu,yu = Graphics.device_to_user(Graphics.getgc(imgc.c), x, y)
        xi, yi = floor(Integer, 1+xu), floor(Integer, 1+yu)
        # println(xi, ", ", yi)
        limit = (img2.zoombb.xmax - img2.zoombb.xmin) * 0.0125 # 100/8000
        annidx = find_idx_of_nearest_pt(lines[1:2,:], [xi, yi], limit)
        if annidx > 0
          # annpt = ([lines[2,annidx], lines[1,annidx]] + offset) / scale 
          annpt = [lines[2,annidx], lines[1,annidx]]
          idx = find_idx_of_nearest_pt(vectors[1:2,:], annpt, 11)
          if idx > 0
            ptA = vectors[1:2,idx] # - params["src_offset"]
            ptB = vectors[3:4,idx] # - params["dst_offset"]
            println(idx, ": ", ptA, ", ", ptB)
            # keep_point = display_blockmatch(params, ptA, ptB)
            # if !keep_point
            #   mask[idx] = false
            #   update_annotations(imgc, img2, original_lines, mask)
            #   push!(indices_to_remove, idx)
            # end
            inspect_window = show_blockmatch(matches, idx, params)
            # inspect_window = display_blockmatch(params, ptA, ptB)
            inspected_index_removed = false
            inspected_index = idx
          end
        end
    end

    function remove_inspected_match()
      if !inspected_index_removed
        if inspected_index > 0
          println(inspected_index, ": ", original_lines[1:2, inspected_index])
          mask[inspected_index] = false
          update_annotations(imgc, img2, original_lines, mask)
          push!(indices_to_remove, inspected_index)
          inspected_index_removed = true
          destroy(inspect_window)
          PyPlot.close()
        end
      end
    end

  function exit_loop()
    break_review = true
    end_edit()
  end

  function end_edit()
    println("End edit\n")
    notify(e)
    bind(c, "<Button-3>", path->path)
    bind(c, "<Control-Button-3>", path->path)
    bind(win, "<Delete>", path->path)
    bind(win, "<Destroy>", path->path)
    bind(win, "<Escape>", path->path)
    bind(win, "<Return>", path->path)
    bind(win, "z", path->path)
    destroy(win)
  end

    # println("1) Right click to inspect correspondences\n",
    #         "2) Ctrl + right click to remove correspondences\n",
    #         "3) Exit window or press Escape")
    wait(e)

    return indices_to_remove, break_review
end

"""
Display matches index k as overlayed images with points
"""
function inspect_matches(meshset, k, prefix="review")
  matches = meshset.matches[k]
  indexA = matches.src_index
  indexB = matches.dst_index

  path = get_review_filename(prefix, indexB, indexA)
  if !isfile(path)
    path = get_review_filename(prefix, indexA, indexB)
  end
  img = h5read(path, "img")
  offset = h5read(path, "offset")
  scale = h5read(path, "scale")

  # Add border to the image for vectors that extend
  # pad = 200
  # img = zeros(UInt32, size(img,1)+pad*2, size(img,2)+pad*2)
  # img[pad:end-pad, pad:end-pad] = img_orig
  # img = vcat(img, ones(UInt32, 400, size(img, 2)))

  params = meshset.properties["params"]["match"]
  params["scale"] = scale
  params["thumb_offset"] = offset
  params["src_index"] = matches.src_index
  params["dst_index"] = matches.dst_index
  params["src_offset"] = get_offset(meshset.meshes[find_mesh_index(meshset, indexA)])
  params["dst_offset"] = get_offset(meshset.meshes[find_mesh_index(meshset, indexB)])
  params["src_size"] = get_image_sizes(matches.src_index)
  params["dst_size"] = get_image_sizes(matches.dst_index)

  src_nodes, dst_nodes, filtered_inds = get_globalized_correspondences(meshset, k)
  # src_nodes, dst_nodes, filtered_inds = get_globalized_correspondences_post(meshset, k)
  vectorsA = scale_matches(src_nodes, scale)
  vectorsB = scale_matches(dst_nodes, scale)
  vecs = offset_matches(vectorsA, vectorsB, offset)
  vectors = [hcat(vecs[1]...); hcat(vecs[2]...)]

  imview = view(img, pixelspacing=[1,1])
  big_vecs = change_vector_lengths([hcat(vecs[1]...); hcat(vecs[2]...)], 2)
  an_pts, an_vectors = show_vectors(imview..., big_vecs, RGB(0,0,1), RGB(1,0,1))
  return imview, matches, vectors, copy(an_vectors.ann.data.lines), params
end

function get_inspection_path(username, stage_name)
  return joinpath(INSPECTION_DIR, string(stage_name, "_inspection_", username, ".txt"))
end

"""
The only function called by tracers to inspect montage points
"""
function inspect_montages(username, meshset_ind, match_ind)
  path = get_inspection_path(username, "montage")
  indrange = get_index_range((1,1,-2,-2), (8,173,-2,-2))
  meshset = load(indrange[meshset_ind])
  println("\n", meshset_ind, ": ", indrange[meshset_ind], " @ ", match_ind, " / ", length(meshset.matches))
  imview, matches, vectors, lines, params = inspect_matches(meshset, match_ind, "seam");
  indices_to_remove, break_review = edit_matches(imview..., matches, vectors, params);
  if !break_review
    store_points(path, meshset, match_ind, indices_to_remove, username, "manual")
    match_ind += 1
    if match_ind > length(meshset.matches)
      meshset_ind += 1
      match_ind = 1
    end
    inspect_montages(username, meshset_ind, match_ind)
  end
end

"""
The only function called by tracers to inspect montage points
"""
function inspect_prealignments(username, meshset_ind, match_ind=1)
  path = get_inspection_path(username, "prealignment")
  index_pairs = collect(get_sequential_index_pairs((1,1,-2,-2), (2,3,-2,-2)))
  indexA, indexB = index_pairs[meshset_ind]
  meshset = load(indexB, indexA)
  println("\n", meshset_ind, ": ", (indexB, indexA), " @ ", match_ind, " / ", length(meshset.matches))
  imview, matches, vectors, lines, params = inspect_matches(meshset, match_ind, "thumb");
  indices_to_remove, break_review = edit_matches(imview..., matches, vectors, params);
  # if !break_review
  #   store_points(path, meshset, match_ind, indices_to_remove, username, "manual")
  #   match_ind += 1
  #   if match_ind > length(meshset.matches)
  #     meshset_ind += 1
  #     match_ind = 1
  #   end
  #   inspect_prealignments(username, meshset_ind, match_ind)
  # end
end

"""
Combine stack error log files of all tracers to create one log matrix
"""
function compile_tracer_montage_review_logs()
  tracers = ["hmcgowan", "bsilverman", "merlinm", "kpw3"]
  logs = []
  for tracer in tracers
    path = get_inspection_path(tracer, "montage")
    if isfile(path)
      push!(logs, readdlm(path))
    end
  end
  return vcat(logs...)
end

"""
Display time-based chart of montage point inspections for the tracers
"""
function show_montage_inspection_progress(show_stats=false)
  path = joinpath(MONTAGED_DIR, "review")
  montages = get_index_range((1,1,-2,-2), (8,173,-2,-2))
  factor = 100
  x = 1:(factor*length(montages))
  y = zeros(Int64, factor*length(montages))
  logs = compile_tracer_montage_review_logs()
  tracers = unique(logs[:, 2])
  fig, ax = PyPlot.subplots()
  for tracer in tracers
    log = logs[logs[:,2] .== tracer, :]
    log_time = round(Int64, (log[:,1] % 10^6) / 100)
    meshset_indices = [(parse_index(l)[1:2]..., -2, -2) for l in log[:,3]]
    log_k = map(x -> findfirst(montages, x)*factor, meshset_indices)
    log_k += log[:,5]
    y[log_k] = log_time
    ax[:plot](log_k, log_time, ".", label=tracer)
    if show_stats
      times = log[sortperm(log[:, 1]), 1]
      dt = [times[i] - times[i-1] for i in 2:length(times)]
      dt_med = median(dt)
      reviews = size(log,1)
      first_day = round(Int, minimum(times) / 1000000) % 10
      last_day = round(Int, maximum(times) / 1000000) % 10
      work_hrs = 8
      println(tracer, ": ", dt_med, " s, ", reviews, ", ", round(Int, reviews/(last_day-first_day+1)/8), " seams/hr")
    end
  end
  ax[:legend](loc="best")
  x_wo = x[y.==0]
  x_wo = x_wo[0 .< x_wo % factor .<= 84]
  PyPlot.plot(x_wo, zeros(Int64, length(x_wo)), ".")
  seams = [join([logs[i,3], logs[i,4]]) for i in 1:size(logs, 1)]
  println("Reviewed seams: ", length(unique(seams)), " / ", sum(y.>0) + length(x_wo))
end

"""
Turn index into a ten-based integer
"""
function create_index_id(ind::Index)
  return ind[1]*10^7 + ind[2]*10^4 + ind[3]*10^2 + ind[4]
end

"""
Create integer from two indices
"""
function create_seam_id(indexA::Index, indexB::Index)
  return create_index_id(indexA)*10^8 + create_index_id(indexB)
end

"""
Filter logs by most recent entry for each seam
"""
function get_most_recent_logs(logs)
  logs = logs[sortperm(logs[:,1]), :]
  indicesA = [parse_index(l) for l in logs[:,3]]
  indicesB = [parse_index(l) for l in logs[:,4]]
  seam_id = [create_seam_id(a,b) for (a,b) in zip(indicesA, indicesB)]
  logs = hcat(logs, seam_id)
  logs = logs[sortperm(logs[:,end]), :]
  last_id = vcat([logs[i,end] != logs[i+1,end] for i=1:(size(logs,1)-1)], true)
  return logs[last_id .== true, :]
end

function update_montage_meshsets(waferA, secA, waferB, secB)
  indices = get_index_range((waferA,secA,-2,-2), (waferB,secB,-2,-2))
  logs = compile_tracer_montage_review_logs()
  logs = get_most_recent_logs(logs)
  for ind in indices
    meshset = get_meshset_with_edits(ind, logs)
    save(meshset)
    solve!(meshset, method="elastic")
    save(meshset)
  end
end

function get_meshset_with_edits(ind::Index, logs)
  meshset = load(ind)
  meshset_indices = [(parse_index(l)[1:2]..., -2, -2) for l in logs[:,3]]
  logs = logs[meshset_indices .== ind, :]
  for i in 1:size(logs,1)
    match = meshset.matches[logs[i,5]]
    inds_to_filter = [logs[i,6]]
    if typeof(inds_to_filter[1]) != Int64
      inds_to_filter = readdlm(IOBuffer(logs[i,6]), ',', Int)
    end
    if inds_to_filter[1] != 0
      filter_manual!(match, inds_to_filter)
    end
  end
  return meshset
end