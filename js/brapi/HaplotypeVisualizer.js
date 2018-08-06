(function(global, factory) {
    typeof exports === 'object' && typeof module !== 'undefined' ? module.exports = factory() :
        typeof define === 'function' && define.amd ? define(factory) :
        (global.PedigreeViewer = factory());
}(this, (function() {
    'use strict';

    function PedigreeViewer(server, auth, urlFunc, errFunc) {
        var pdgv = {};
        var brapijs = BrAPI(server, auth);
        var root = null;
        var access_token = null;
        var loaded_nodes = {};
        var myTree = null;
        var locationSelector = null;

        urlFunc = urlFunc != undefined ? urlFunc : function() {
            return null
        };

        pdgv.newTree = function(stock_ids, marker_ids, protocol, callback) {
            root = stock_ids[0];
            loaded_nodes = {};
            var all_nodes = [];
            load_nodes(stock_ids, function(nodes) {
                [].push.apply(all_nodes, nodes);
                var mothers = nodes.map(function(d) {
                    return d.mother_id
                });
                var fathers = nodes.map(function(d) {
                    return d.father_id
                });
                var parents = mothers.concat(fathers).filter(function(d, index, self) {
                    return d !== undefined &&
                        d !== null &&
                        loaded_nodes[d] === undefined &&
                        self.indexOf(d) === index;
                });

                $.ajax({
                    url: '/ajax/haplotype_vis/marker_values',
                    type: 'POST',
                    contentType: 'application/json',
                    dataType: 'json',
                    data: JSON.stringify({
                        "marker_list": marker_ids,
                        "accession_list": stock_ids,
                        "protocol": protocol
                    }),
                    success: function(data) {
                        for (var i = 0; i < all_nodes.length; i++) {
                            all_nodes[i].markers = marker_ids.reduce(function(result, element) {
                                var genotype = data.marker_values[all_nodes[i].id][element].GT;
                                if (genotype != null) {
                                    var obj = {};
                                    obj.key = element;
                                    if(genotype[0] == '0') {
                                        obj.value1 = data.marker_values[all_nodes[i].id][element].REF;
                                    } else if(genotype[0] == '1') {
                                        obj.value1 = data.marker_values[all_nodes[i].id][element].ALT;
                                    } else {
                                        obj.value1 = '?';
                                    }
                                    if(genotype[2] == '0') {
                                        obj.value2 = data.marker_values[all_nodes[i].id][element].REF;
                                    } else if(genotype[2] == '1') {
                                        obj.value2 = data.marker_values[all_nodes[i].id][element].ALT;
                                    } else {
                                        obj.value2 = '?';
                                    }
                                    result.push(obj);
                                }
                                return result;
                            }, []);
                        }

                        createNewTree(all_nodes, marker_ids);
                        callback.call(pdgv);
                    },
                    error: function() {
                        errFunc();
                    }
                });
            });
        };

        pdgv.drawViewer = function(loc, draw_width, draw_height, marker_ids) {
            locationSelector = loc;
            drawTree(undefined, draw_width, draw_height, marker_ids);
        };

        function createNewTree(start_nodes, marker_ids) {
            // Calculating maximum marker width
            var width = 0;
            for (var i = 0; i < marker_ids.length; i++) {
                if (width < marker_ids[i].length) {
                    width = marker_ids[i].length;
                }
            }
            width = width * 50;

            myTree = d3.pedigreeTree()
                .levelWidth(280 + 20 * marker_ids.length)
                .levelMidpoint(50)
                .nodePadding(width)
                .nodeWidth(20)
                .linkPadding(20)
                .vertical(true)
                .parentsOrdered(true)
                .parents(function(node) {
                    return [loaded_nodes[node.mother_id], loaded_nodes[node.father_id]].filter(Boolean);
                })
                .id(function(node) {
                    return node.id;
                })
                .groupChildless(false)
                .iterations(50)
                .data(start_nodes)
                .excludeFromGrouping([root]);
        }

        function load_nodes(stock_ids, callback) {
            var germplasm = brapijs.germplasm_search({
                'germplasmDbIds': stock_ids
            });
            var pedigrees = germplasm.germplasm_pedigree(function(d) {
                return {
                    'germplasmDbId': d.germplasmDbId
                }
            });
            var progenies = germplasm.germplasm_progeny(function(d) {
                return {
                    'germplasmDbId': d.germplasmDbId,
                    'pageSize': 999
                }
            }, "map");
            pedigrees.join(progenies, germplasm).filter(function(ped_pro_germId) {
                if (ped_pro_germId[0] === null || ped_pro_germId[1] === null) {
                    console.log("Failed to load progeny or pedigree for " + ped_pro_germId[2]);
                    return false;
                }
                return true;
            }).map(function(ped_pro_germId) {
                var mother = null,
                    father = null;
                if (ped_pro_germId[0].parent1Type == "FEMALE") {
                    mother = ped_pro_germId[0].parent1DbId;
                }
                if (ped_pro_germId[0].parent1Type == "MALE") {
                    father = ped_pro_germId[0].parent1DbId;
                }
                if (ped_pro_germId[0].parent2Type == "FEMALE") {
                    mother = ped_pro_germId[0].parent2DbId;
                }
                if (ped_pro_germId[0].parent2Type == "MALE") {
                    father = ped_pro_germId[0].parent2DbId;
                }
                return {
                    'id': ped_pro_germId[2].germplasmDbId,
                    'mother_id': mother,
                    'father_id': father,
                    'name': ped_pro_germId[1].defaultDisplayName,
                    'children': ped_pro_germId[1].progeny.filter(Boolean).map(function(d) {
                        return d.germplasmDbId;
                    })
                };
            }).each(function(node) {
                loaded_nodes[node.id] = node;
            }).all(callback)
            .catch(function(){
                errFunc();
            });
        }

        function drawTree(trans, draw_width, draw_height, marker_ids) {

            var layout = myTree();

            // Set default change-transtion to no duration
            trans = trans || d3.transition().duration(0);

            // Make wrapper(pdg)
            var wrap = d3.select(locationSelector);
            var canv = wrap.select("svg.pedigreeViewer");
            if (canv.empty()) {
                canv = wrap.append("svg").classed("pedigreeViewer", true)
                    .attr("width", "100%")
                    .attr("height", draw_height)
                    .attr("viewbox", "0 0 " + draw_width + " " + draw_height);
            }
            var cbbox = canv.node().getBoundingClientRect();
            var canvw = cbbox.width,
                canvh = cbbox.height;
            var pdg = canv.select('.pedigreeTree');
            if (pdg.empty()) {
                pdg = canv.append('g').classed('pedigreeTree', true);
            }

            // Make background
            var bg = pdg.select('.pdg-bg');
            if (bg.empty()) {
                bg = pdg.append('rect')
                    .classed('pdg-bg', true)
                    .attr("x", -canvw * 500)
                    .attr("y", -canvh * 500)
                    .attr('width', canvw * 1000)
                    .attr('height', canvh * 1000)
                    .attr('fill', "white")
                    .attr('opacity', "0.00001")
                    .attr('stroke', 'none');
            }


            var width = 0;
            for (var i = 0; i < marker_ids.length; i++) {
                if (width < marker_ids[i].length) {
                    width = marker_ids[i].length;
                }
            }

            // Make scaled content/zoom groups
            var padding = 100;
            var pdgtree_width = d3.max([500, layout.x[1] - layout.x[0]]);
            var pdgtree_height = d3.max([500, layout.y[1] - layout.y[0]]);
            var centeringx = d3.max([0, (500 - (layout.x[1] - layout.x[0])) / 2]);
            var centeringy = d3.max([0, (500 - (layout.y[1] - layout.y[0])) / 2]);
            var scale = get_fit_scale(canvw, canvh, pdgtree_width, pdgtree_height, padding);
            var offsetx = (canvw - (pdgtree_width) * scale) / 2 + centeringx * scale - (width + 20);

            var offsety = (canvh - (pdgtree_height) * scale) / 2 + centeringy * scale;
            var content = pdg.select('.pdg-content');
            if (content.empty()) {
                var zoom = d3.zoom();
                var zoom_group = pdg.append('g').classed('pdg-zoom', true).data([zoom]);

                content = zoom_group.append('g').classed('pdg-content', true);
                content.datum({
                    'zoom': zoom
                });
                zoom.on("zoom", function() {
                    zoom_group.attr('transform', d3.event.transform);
                });
                bg.style("cursor", "all-scroll").call(zoom).call(zoom.transform, d3.zoomIdentity);
                bg.on("dblclick.zoom", function() {
                    zoom.transform(bg.transition(), d3.zoomIdentity);
                    return false;
                });

                content.attr('transform',
                    d3.zoomIdentity
                    .translate(offsetx, offsety)
                    .scale(scale)
                );
            }
            content.datum().zoom.scaleExtent([0.5, d3.max([pdgtree_height, pdgtree_width]) / 200]);
            content.transition(trans)
                .attr('transform',
                    d3.zoomIdentity
                    .translate(offsetx, offsety)
                    .scale(scale)
                );

            // Set up draw layers
            var linkLayer = content.select('.link-layer');
            if (linkLayer.empty()) {
                linkLayer = content.append('g').classed('link-layer', true);
            }
            var nodeLayer = content.select('.node-layer');
            if (nodeLayer.empty()) {
                nodeLayer = content.append('g').classed('node-layer', true);
            }

            // Link curve generators
            var stepline = d3.line().curve(d3.curveStepAfter);
            var curveline = d3.line().curve(d3.curveBasis);
            var build_curve = function(d) {
                if (d.type == "parent->mid") return curveline(d.path);
                if (d.type == "mid->child") return stepline(d.path);
            };

            // Draw nodes
            var nodes = nodeLayer.selectAll('.node')
                .data(layout.nodes, function(d) {
                    return d.id;
                });
            var newNodes = nodes.enter().append('g')
                .classed('node', true)
                .attr('transform', function(d) {
                    var begin = d;
                    if (d3.event && d3.event.type == "click") {
                        begin = d3.select(d3.event.target).datum();
                    }
                    return 'translate(' + begin.x + ',' + begin.y + ')'
                });
            var nodeNodes = newNodes.filter(function(d) {
                return d.type == "node";
            });

            nodeNodes.append('rect').classed("node-name-wrapper", true)
                .attr('fill', "white")
                .attr('stroke', "grey")
                .attr('stroke-width', 2)
                .attr("width", 200)
                .attr("height", 20)
                .attr("y", 0)
                .attr("rx", 10)
                .attr("ry", 10)
                .attr("x", -100);

            // Draw node links
            var nodeUrlLinks = nodeNodes.filter(function(d) {
                    var url = urlFunc(d.id);
                    if (url !== null) {
                        d.url = url;
                        return true;
                    }
                    return false;
                })
                .append('a')
                .attr('href', function(d) {
                    return urlFunc(d.id);
                })
                .attr('target', '_blank')
                .append('text').classed('node-name-text', true)
                .attr('y', 15)
                .attr('text-anchor', "middle")
                .text(function(d) {
                    return d.value.name;
                })
                .attr('fill', "black");

            nodeNodes.filter(function(d) {
                    return d.url === undefined;
                })
                .append('text').classed('node-name-text', true)
                .attr('y', 15)
                .attr('text-anchor', "middle")
                .text(function(d) {
                    return d.value.name;
                })
                .attr('fill', "black");

            // Set node width to text width
            nodeNodes.each(function(d) {
                var nn = d3.select(this);
                var ctl = nn.select('.node-name-text').node().getComputedTextLength();
                var w = ctl + 20;
                nn.select('.node-name-wrapper')
                    .attr("width", w)
                    .attr("x", -w / 2);
            });

            // Draw node-marker connection
            nodeNodes.each(function(d) {
                var nn = d3.select(this);
                var ctl = nn.select('.node-name-text').node().getComputedTextLength();
                var w = ctl + 20;
                nn.append('line').classed("node-marker-link", true)
                    .style("stroke-dasharray", ("2, 2"))
                    .attr('fill', 'none')
                    .attr('stroke', "#A9A9A9")
                    .attr('stroke-width', 5)
                    .attr("y1", 10)
                    .attr("y2", 10)
                    .attr("x1", w / 2)
                    .attr("x2", w / 2 + 27);
            });

            // Draw markers
            var markerNodes = nodeNodes.selectAll('.markers')
                .data(function(d) {
                    return d.value.markers;
                })
                .enter().append("g")
                .classed('markers', true);

            nodeNodes.each(function(){
                var nn = d3.select(this);
                var ctl = nn.select('.node-name-text').node().getComputedTextLength();
                var w = ctl + 20;
                nn.selectAll('.markers').append('rect').classed('marker-name-wrapper', true)
                    .attr('fill', "#D3D3D3")
                    .attr('stroke', "black")
                    .attr('stroke-width', 2)
                    .style("opacity", .3)
                    .attr("height", 20)
                    .attr("y", function(d, i) {
                        return 22 * i;
                    })
                    .attr("rx", 10)
                    .attr("ry", 10)
                    .attr("x", w / 2 + 27);
            });

            nodeNodes.each(function(){
                var nn = d3.select(this);
                var ctl = nn.select('.node-name-text').node().getComputedTextLength();
                var w = ctl + 20;
                nn.selectAll('.markers').append('text')
                    .classed('marker-name-text', true)
                    .attr("y", function(d, i) {
                        return 22 * i + 15;
                    })
                    .attr("x", w/2+40)
                    .attr('text-anchor', "left")
                    .text(function(d, i) {
                        return d.key + ': ';
                    })
                    .attr('fill', 'black')
                    .attr('opacity', 1);
            });

            markerNodes.on("mouseover", function(d_selected) {
                    markerNodes.each(function(d_marker){
                        if (d_selected.key != d_marker.key) {
                            var mn = d3.select(this);
                            mn.style('opacity', .3);
                        }
                    });
                })
                .on("mouseout", function() {
                    markerNodes.each(function(){
                            var mn = d3.select(this);
                            mn.style('opacity', 1);
                    });
                });

            // Draw alleles
            var max = 0;
            markerNodes.each(function(d) {
                var mn = d3.select(this);
                var width = mn.select('.marker-name-text').node().getComputedTextLength();
                if (max < width) {
                    max = width;
                }
            });

            // First allele
            markerNodes.each(function(_,i){
                var mn = d3.select(this);
                var w = max + parseFloat(mn.select('.marker-name-text').attr("x")) + 4;
                mn.append ('rect')
                    .classed('first-allele-wrapper', true)
                    .attr('fill', function(d) {
                        if (d.value1 == "A") {
                            return "red";
                        } else if (d.value1 == "T") {
                            return "yellow";
                        } else if (d.value1 == "G") {
                            return "green";
                        } else if (d.value1 == "C"){
                            return "blue";
                        } else {
                            return "white";
                        }
                    })
                    .attr('stroke-width', 1)
                    .style('opacity', .3)
                    .attr("height", 20)
                    .attr("width", 15)
                    .attr("y", function() {
                        return 22 * i;
                    })
                    .attr("x", w);
            });
            markerNodes.each(function(_, i){
                var mn = d3.select(this);
                var w = max + parseFloat(mn.select('.marker-name-text').attr("x")) + 6;
                mn.append('text')
                    .classed('first-allele-text', true)
                    .attr("y", function() {
                        return 22 * i + 15;
                    })
                    .attr("x", function() {
                        return w;
                    })
                    .text(function(d) {
                        return d.value1;
                    })
                    .attr('fill', 'black')
                    .attr('opacity', 1);
            });

            // Second allele
            markerNodes.each(function(_,i){
                var mn = d3.select(this);
                var w = parseFloat(mn.select('.first-allele-text').attr("x")) + 13;
                mn.append ('rect')
                    .classed('second-allele-wrapper', true)
                    .attr('fill', function(d) {
                        if (d.value2 == "A") {
                            return "red";
                        } else if (d.value2 == "T") {
                            return "yellow";
                        } else if (d.value2 == "G") {
                            return "green";
                        } else if (d.value2 == "C"){
                            return "blue";
                        } else {
                            return "white";
                        }
                    })
                    .attr('stroke-width', 1)
                    .style('opacity', .3)
                    .attr("height", 20)
                    .attr("width", 15)
                    .attr("y", function() {
                        return 22 * i;
                    })
                    .attr("x", w);
            });
            markerNodes.each(function(_, i){
                var mn = d3.select(this);
                var w = parseFloat(mn.select('.first-allele-text').attr("x")) + 15;
                mn.append('text')
                    .classed('second-allele-text', true)
                    .attr("y", function() {
                        return 22 * i + 15;
                    })
                    .attr("x", function() {
                        return w;
                    })
                    .text(function(d) {
                        return d.value2;
                    })
                    .attr('fill', 'black')
                    .attr('opacity', 1);
            });


            // Set marker width to text width
            var max = 0;
            markerNodes.each(function(d) {
                var mn = d3.select(this);
                var width = mn.select('.marker-name-text').node().getComputedTextLength();
                if (max < width) {
                    max = width;
                }
            });
            nodeNodes.each(function(){
                markerNodes.each(function(d) {
                    var mn = d3.select(this);
                    var w_marker = max + 60;
                    mn.select('.marker-name-wrapper')
                        .attr("width", w_marker)
                });
            });

            // Link colors
            var link_color = function(d) {
                if (d.type == "mid->child") return d3.rgb(115, 60, 170);
                if (d.type == "parent->mid") {
                    // If its the first parent, red. Otherwise, blue.
                    var representative = d.sinks[0].type == "node-group" ?
                        d.sinks[0].value[0].value :
                        d.sinks[0].value;
                    if (representative.mother_id == d.source.id) {
                        return d3.rgb(240, 30, 30);
                    } else {
                        return d3.rgb(65, 85, 220);
                    }
                }
                return 'gray';
            };

            // Make links
            var links = linkLayer.selectAll('.link')
                .data(layout.links, function(d) {
                    return d.id;
                });
            var newLinks = links.enter().append('g')
                .classed('link', true);
            newLinks.append('path')
                .attr('d', function(d) {
                    var begin = (d.sink || d.source);
                    if (d3.event && d3.event.type == "click") {
                        begin = d3.select(d3.event.target).datum();
                    }
                    return curveline([
                        [begin.x, begin.y],
                        [begin.x, begin.y],
                        [begin.x, begin.y],
                        [begin.x, begin.y]
                    ]);
                })
                .attr('fill', 'none')
                .attr('stroke', link_color)
                .attr('opacity', function(d) {
                    if (d.type == "parent->mid") return 0.7;
                    return 0.999;
                })
                .attr('stroke-width', 4);
            var allLinks = newLinks.merge(links);
            allLinks.transition(trans).select('path').attr('d', build_curve);
        }

        return pdgv;
    }

    function get_fit_scale(w1, h1, w2, h2, pad) {
        w1 -= pad * 2;
        h1 -= pad * 2;
        if (w1 / w2 < h1 / h2) {
            return w1 / w2;
        } else {
            return h1 / h2;
        }
    }

    return PedigreeViewer;

})));
