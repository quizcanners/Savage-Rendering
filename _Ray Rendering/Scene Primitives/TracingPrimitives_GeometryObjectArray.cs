using PainterTool;
using QuizCanners.Inspect;
using QuizCanners.Utils;
using System;
using System.Collections.Generic;
using Unity.Collections;
using Unity.Jobs;
using UnityEngine;

namespace QuizCanners.VolumeBakedRendering
{
    public static partial class TracingPrimitives
    {
        // TODO: Reduce the main box size to potentially group out
        internal const int MAX_BOUNDING_BOXES_COUNT = 64; // Modify ARRAY_BOX_COUNT in PrimitiveScenes.cginc
        public const int MAX_ELEMENTS_COUNT = 256; // Modify ARRAY_SIZE in PrimitiveScenes.cginc
        internal const int MAX_BINARY_TREE_BOXES_COUNT = 64; // Modify BINARY_TREE_SIZE
       

        [Serializable]
        internal class GeometryObjectArray : IGotName, IPEGI, IPEGI_Handles, INeedAttention
        {
           
            [SerializeField] private string _parameterName;
            [SerializeField] public Shape ShapeToReflect = Shape.Cube;

            internal SortedElement[] SortedElements;

            ShaderProperty.VectorArrayValue _positionAndMaterial;
            ShaderProperty.VectorArrayValue _size;
            ShaderProperty.VectorArrayValue _colorAndRoughness;
            ShaderProperty.VectorArrayValue _rotation;

            ShaderProperty.VectorValue _boundingBox_Position;
            ShaderProperty.VectorValue _boundingBox_Size; // W is Boxes count

            ShaderProperty.VectorArrayValue _boundingBoxes_Positions;
            ShaderProperty.VectorArrayValue _boundingBoxes_Sizes;

            
            // 0,1 - first branch, second branch. Negative - inverse index of the leaf - 1
            ShaderProperty.VectorArrayValue _binaryTree_Position; // W is first Branch/Leaf 
            ShaderProperty.VectorArrayValue _binaryTree_Sizes; // W is second Branch/Leaf
            ShaderProperty.VectorValue _binaryTree_Count;


            private int _totalBoxes;

            private readonly Gate.Bool _setInShader = new();

            readonly Vector4[] positionArray = new Vector4[MAX_ELEMENTS_COUNT];
            readonly Vector4[] colorArray = new Vector4[MAX_ELEMENTS_COUNT];
            readonly Vector4[] rotationArray = new Vector4[MAX_ELEMENTS_COUNT];
            readonly Vector4[] sizeArray = new Vector4[MAX_ELEMENTS_COUNT];

            readonly Vector4[] boundingPosition = new Vector4[MAX_BOUNDING_BOXES_COUNT];
            readonly Vector4[] boundingExtents = new Vector4[MAX_BOUNDING_BOXES_COUNT];


            //16 16                 2
            //8 8 8 8               4
            //4 4 4 4 4 4 4 4       8
            //2 2 2 2 2 2 2 2  ... 16
            //30

            // Binary tree

        

            readonly Vector4[] binaryTree_Positions = new Vector4[MAX_BINARY_TREE_BOXES_COUNT];
            readonly Vector4[] binaryTree_Sizes = new Vector4[MAX_BINARY_TREE_BOXES_COUNT];

            private BinaryTreeBranch _binaryTreePartition;

            readonly BoundingBoxCalculator _allElementsBox = new();
            private readonly List<BoundingBox> elementsToGroup = new();
            private readonly Dictionary<C_RayT_PrimitiveRoot, List<SortedElement>> elementsPreGrouped = new();
            private NativeArray<BoxForJob> boxesForJob;
            private NativeArray<BoxJobMeta> _jobMeta;
            JobHandle handle;
            BoxesJob job;

            private BoxesSortingStage _sortingStage;

            public bool IsJobCompletedDone => _sortingStage == BoxesSortingStage.Completed || handle.IsCompleted;

            private enum BoxesSortingStage { Uninitialized, JobStarted, Completed }

            void GenerateBinarySearchTree()
            {
                if (_totalBoxes < 2)
                    return;
                
                _binaryTreePartition = new(center: _allElementsBox.Center, size: _allElementsBox.Size, 0);

                if (VolumeTracing.TryGetLatestCfg(out var vol))
                {
                    _binaryTreePartition.RequestABranch(center: vol.DesiredCenter, size: vol.GetSize() * 1.5f);
                }

                for (int i = 0; i < _totalBoxes; i++)
                {
                    var leaf = new Leaf
                    {
                        Box = new BoundingBoxCalculator
                        {
                            Center = boundingPosition[i],
                            Size = boundingExtents[i]
                        },
                        index = i
                    };

                    _binaryTreePartition.Consume(leaf);
                }

                int nodeIndex = 0;
                _binaryTreePartition.IndexNodes(ref nodeIndex);
                _binaryTreePartition.GenerateTree(binaryTree_Positions, binaryTree_Sizes);

                _binaryTree_Position.GlobalValue = binaryTree_Positions;
                _binaryTree_Sizes.GlobalValue = binaryTree_Sizes;
                _binaryTree_Count.GlobalValue = new Vector4(nodeIndex, 0, 0, 0);
            }



            private void InitializeIfNotInitialized()
            {
                if (_setInShader.TryChange(true))
                {
                    _positionAndMaterial = new(_parameterName);
                    _size = new(_parameterName + "_Size");
                    _colorAndRoughness = new(_parameterName + "_Mat");
                    _rotation = new(_parameterName + "_Rot");
                    _boundingBoxes_Positions = new(_parameterName + "_BoundPos");
                    _boundingBoxes_Sizes = new(_parameterName + "_BoundSize");

                    _boundingBox_Position = new(_parameterName + "_BoundPos_All");
                    _boundingBox_Size = new(_parameterName + "_BoundSize_All");

                    _binaryTree_Position = new(_parameterName + "_BinaryTree_PosNL");
                    _binaryTree_Sizes = new(_parameterName + "_BinaryTree_SizeNR");
                    _binaryTree_Count = new(_parameterName + "_BinaryTree_Count"); ;

                }
            }

            /*
            private void GroupBoundingBoxes() 
            {
                boxes.Clear();
                foreach (var prim in SortedElements) 
                {
                    if (!prim.IsHidden)
                    {
                        boxes.Add(new BoundingBox(prim));
                    }
                }

                while (boxes.Count > MAX_BOUNDING_BOXES_COUNT)
                {
                    Efficiency bestEfficiency = new();

                    for (int i = boxes.Count - 1; i >= 0; i--)
                    {
                        var toEncapsulate_I = boxes[i];

                        if (TryEncapsulate())
                        {
                            bestEfficiency = new();
                            continue;
                        }

                        bool TryEncapsulate()
                        {
                            for (int j = 0; j < i; j++)
                            {
                                if (boxes[j].TryEncapsulate(toEncapsulate_I, out float efficiency))
                                {
                                    boxes.RemoveAt(i);
                                    return true;
                                }

                                if (efficiency > bestEfficiency.Value)
                                {
                                    bestEfficiency.Value = efficiency;
                                    bestEfficiency.Index_Bigger = j;
                                    bestEfficiency.Index_Smaller = i;
                                }
                            }

                            return false;
                        }
                    }

                    if (bestEfficiency.Value > 0)
                    {
                        boxes[bestEfficiency.Index_Bigger].Encapsulate(boxes[bestEfficiency.Index_Smaller]);
                        boxes.RemoveAt(bestEfficiency.Index_Smaller);
                    } else 
                    {
                        boxes[^1].Encapsulate(boxes[^2]);
                        boxes.RemoveAt(boxes.Count - 2);
                        Debug.LogError("Failed to group boxes. Merging random");
                    }
                }
            }*/

            public void Clear() 
            {
                if (_sortingStage == BoxesSortingStage.JobStarted) 
                {
                    handle.Complete();
                }

                DisposeJob();

                _sortingStage = BoxesSortingStage.Uninitialized;
            }

            #region Jobs

            private void DisposeJob()
            {
                if (boxesForJob.IsCreated)
                {
                    boxesForJob.Dispose();
                    _jobMeta.Dispose();
                }
            }

            public void StartGroupingBoxesJob()
            {
                if (_sortingStage == BoxesSortingStage.JobStarted)
                {
                    Clear();
                }

                elementsToGroup.Clear();
                elementsPreGrouped.Clear();

                if (SortedElements.Length == 0) 
                {
                    _sortingStage = BoxesSortingStage.Completed;
                    return;
                }

                _sortingStage = BoxesSortingStage.JobStarted;

                var timer = QcDebug.TimeProfiler.Instance["Box Grouping"];

                List<BoxForJob> jobBoxes;

                using (timer.Last("Creating List").Start())
                {
                    jobBoxes = new();

                    foreach (SortedElement prim in SortedElements)
                    {
                        var parent = prim.Original.RootParent;

                        if (parent) 
                        {
                            elementsPreGrouped.GetOrCreate(parent).Add(prim);
                            continue;
                        }

                        Bounds bounds = prim.BoundingBox;
                        BoxForJob el = new(bounds.min, bounds.max, jobBoxes.Count);
                        jobBoxes.Add(el);
                        elementsToGroup.Add(new BoundingBox(prim));
                    }
                }

                int boxesLeftToSort = MAX_BOUNDING_BOXES_COUNT - elementsPreGrouped.Count;

                if (elementsToGroup.Count == 0 || boxesLeftToSort <=0) 
                {
                    _sortingStage = BoxesSortingStage.Completed;
                    return;
                }

                using (timer.Last("Creating Native Array and Job").Start())
                {
                    boxesForJob = new NativeArray<BoxForJob>(jobBoxes.ToArray(), Allocator.Persistent);
                }

                using (timer.Last("Creating Job").Start())
                {
                    var meta = new BoxJobMeta()
                    {
                        LoopsCounter = 1000,
                        MaxVoundingBoxesCount = boxesLeftToSort,
                    };

                    _jobMeta = new NativeArray<BoxJobMeta>(1, Allocator.Persistent);

                    _jobMeta[0] = meta;

                    job = new BoxesJob(boxesForJob, _jobMeta);
                }

                using (timer.Last("Job").Start())
                {
                    handle = job.Schedule();
                }
            }

            public void ProcessBoxesAfterJob()
            {
                if (_sortingStage == BoxesSortingStage.Completed)
                    return;

                handle.Complete();

                _sortingStage = BoxesSortingStage.Completed;

                Dictionary<int, int> finalBoxes = new();

                for (int i = 0; i < elementsToGroup.Count; i++)
                {
                    BoxForJob boxFromJob = boxesForJob[i];

                    if (!boxFromJob.IsEncapsulaed)
                        continue;

                    BoundingBox box = elementsToGroup[i];

                    HashSet<int> path = new();

                    bool matched = false;

                    do
                    {
                        if (finalBoxes.TryGetValue(boxFromJob.EncapsulatedInto, out var finalBox1))
                        {
                            elementsToGroup[finalBox1].Encapsulate(box);
                            SetPath(finalBox1);
                            matched = true;
                            break;
                        }

                        path.Add(boxFromJob.Index);

                        boxFromJob = boxesForJob[boxFromJob.EncapsulatedInto];
                        
                    } while (boxFromJob.IsEncapsulaed);

                    if (matched)
                        continue;

                    var finalBox = boxFromJob.Index;


                    elementsToGroup[finalBox].Encapsulate(box);
                    SetPath(finalBox);


                    void SetPath(int index)
                    {
                        foreach (var p in path)
                            finalBoxes[p] = index;
                    }

                }

                for (int i = elementsToGroup.Count-1; i >= 0; i--)
                {
                    if (!boxesForJob[i].IsEncapsulaed)
                        continue;

                    elementsToGroup.RemoveAt(i);
                }

                DisposeJob();
            }

            #endregion

           



            public void PassToShader() 
            {
                InitializeIfNotInitialized();

                _allElementsBox.Reset();

                int totalIndex = 0;
                int startIndex = 0;

                if (elementsToGroup.Count == 0 && elementsPreGrouped.Count == 0)
                {
                    _allElementsBox.Center = Vector3.zero;
                    _allElementsBox.Size = Vector3.one;
                }

                int boxIndex = 0;

                // Elements from defined boxes
                foreach (var group in elementsPreGrouped) 
                {
                    var list = group.Value;

                    var box = new BoundingBoxCalculator();

                    foreach (SortedElement el in list) 
                    {
                        Add(el);
                        box.Add(el.BoundingBox);
                    }

                    FinalizeBox(box.Center, box.Extents);
                }

                for (int b = 0; b < elementsToGroup.Count; b++)
                {
                    BoundingBox box = elementsToGroup[b];

                    for (int p = 0; p < box.Primitives.Count; p++)
                    {
                        SortedElement prim = box.Primitives[p];

                        Add(prim);
                    }

                    FinalizeBox(box.Calculator.Center, box.Calculator.Extents);
                }

                void Add(SortedElement prim)
                {
                    _allElementsBox.Add(prim.BoundingBox);

                    positionArray[totalIndex] = prim.SHD_PositionAndMaterial;
                    colorArray[totalIndex] = prim.SHD_ColorAndRoughness;
                    rotationArray[totalIndex] = prim.SHD_Rotation;
                    sizeArray[totalIndex] = prim.Size;//SHD_Extents;
                    totalIndex++;
                }

                void FinalizeBox(Vector3 center, Vector3 extends)
                {
                    boundingPosition[boxIndex] = center.ToVector4(startIndex);
                    boundingExtents[boxIndex] = extends.ToVector4(totalIndex);
                    startIndex = totalIndex;
                    boxIndex++;
                }

                // Boxes

                _totalBoxes = boxIndex;

                _boundingBox_Position.GlobalValue = _allElementsBox.Center;
                _boundingBox_Size.GlobalValue = _allElementsBox.Extents.ToVector4(boxIndex);//elementsToGroup.Count);

                _boundingBoxes_Positions.GlobalValue = boundingPosition;
                _boundingBoxes_Sizes.GlobalValue = boundingExtents;

                // Elements
                _positionAndMaterial.GlobalValue = positionArray;
                _size.GlobalValue = sizeArray;
                _colorAndRoughness.GlobalValue = colorArray;
                _rotation.GlobalValue = rotationArray;

                try
                {
                    GenerateBinarySearchTree();
                } catch (Exception ex) 
                {
                    Debug.LogException(ex);
                }
            }


            #region Inspector

            public override string ToString() => _parameterName;
            public string NameForInspector
            {
                get => _parameterName;
                set
                {
                    _setInShader.ValueIsDefined = false;
                    _parameterName = value;
                }
            }

            private readonly pegi.EnterExitContext context = new();

            void IPEGI.Inspect()
            {
                using (context.StartContext())
                {
                    if (context.IsAnyEntered == false)
                    {
                        "Name".PegiLabel().Edit_Delayed(ref _parameterName).Nl(()=> _setInShader.ValueIsDefined = false);
                      //  "Rotation".PegiLabel().ToggleIcon(ref SupportsRotation).Nl();
                    }

                    if ("Registered Primitives [{0}]".F(SortedElements == null ? "null" : SortedElements.Length.ToString()).PegiLabel().IsEntered().Nl())
                    {
                        "Sorted elements".PegiLabel().Edit_Array(ref SortedElements).Nl();
                    }

                    if (context.IsCurrentEntered)
                    {
                        "Pass {0} Elements To Array".F(MAX_ELEMENTS_COUNT).PegiLabel().Click(StartGroupingBoxesJob).Nl();
                    }

                    "Bounding Boxes".PegiLabel().Enter_List(elementsToGroup).Nl();

                    /*
                    if (context.IsCurrentEntered)
                    {
                        pegi.Click(GroupBoundingBoxes).Nl();
                    }*/

                    if ("Boxes Job".PegiLabel().IsEntered().Nl()) 
                    {
                        switch (_sortingStage) 
                        {
                            case BoxesSortingStage.Uninitialized:
                                if ("Run Job".PegiLabel().Click().Nl())
                                {
                                    StartGroupingBoxesJob();
                                    
                                }
                                break;
                            case BoxesSortingStage.JobStarted:

                                if (handle.IsCompleted && "Complete".PegiLabel().Click())
                                    ProcessBoxesAfterJob();
                                 
                                break;
                            case BoxesSortingStage.Completed:

                                if (_jobMeta != null && _jobMeta.Length > 0)
                                {
                                    var meta = _jobMeta[0];
                                    pegi.Nested_Inspect(ref meta).Nl();
                                }

                                /*
                                if (boxesForJob != null)
                                    for (int i = 0; i < boxesForJob.Length; i++)
                                    {
                                        BoxForJob el = boxesForJob[i];
                                        if (el.EncapsulatedInto != -1)
                                            continue;

                                        el.Inspect();
                                    }
                                */
                                if ("Pass To Shader".PegiLabel().Click().Nl())
                                {
                                    _sortingStage = BoxesSortingStage.Uninitialized;
                                    PassToShader();
                                }

                                break;
                        }

                        

                    }

                    if ("Binary tree partition".PegiLabel().IsEntered().Nl())
                    {
                        pegi.Click(GenerateBinarySearchTree).Nl();

                        if (_binaryTreePartition != null && "Clear the tree".PegiLabel().Click().Nl())
                            _binaryTreePartition = null;


                        if (_binaryTree_Count.GlobalValue.x > 0)
                        {
                            int count = (int)_binaryTree_Count.GlobalValue.x;
                            for (int i= 0; i < count; i++) 
                            {
                                "({0}, {1})".F(binaryTree_Positions[i].w, binaryTree_Sizes[i].w).PegiLabel().Nl();
                            }
                        }

                    }
                }
            }

            public void OnSceneDraw()
            {

                if (_binaryTreePartition != null)
                {
                    _binaryTreePartition.OnSceneDraw_Nested();
                    return;
                }

                /*
                _allElementsBox.OnSceneDraw_Nested();

                foreach (var b in elementsToGroup)
                    b.OnSceneDraw_Nested();*/

                using (pegi.SceneDraw.SetColorDisposible(Color.gray))
                {
                    for (int i = 0; i < _totalBoxes; i++)
                    {
                        pegi.Handle.DrawWireCube(boundingPosition[i], boundingExtents[i] * 2);
                    }
                }
            }

            public string NeedAttention()
            {
                if (_sortingStage == BoxesSortingStage.Completed) 
                {
                    if (_totalBoxes == 1)
                        return "Got only one box. Sorting couldn't process. Nothing will be shown";
                }

                return null;
            }

            #endregion

            private class BoundingBox : IPEGI_Handles, IPEGI_ListInspect
            {
                public BoundingBoxCalculator Calculator = new();
                public List<SortedElement> Primitives = new();

                public bool TryEncapsulate(BoundingBox other, out float efficiency)
                {
                    float coefficient = other.Primitives.Count + Primitives.Count;

                    efficiency = Calculator.GetEncapsulationEfficiency(other.Calculator, coefficient: 1f / coefficient);

                    if (efficiency >= 2)
                    {
                        Encapsulate(other);
                        return true;
                    }
                    return false;
                }

                public void Encapsulate(BoundingBox other)
                {
                    Calculator.Add(other.Calculator);
                    Primitives.AddRange(other.Primitives);
                }

                public void OnSceneDraw()
                {
                    using (pegi.SceneDraw.SetColorDisposible(Color.yellow))
                    {
                        Calculator.OnSceneDraw();
                    }
                }

                public override string ToString() => "{0} elements. Volume: {1}".F(Primitives.Count, Calculator.ToString());

                public void InspectInList(ref int edited, int index)
                {
                    ToString().PegiLabel().Nl();
                }

                public BoundingBox(SortedElement startElement)
                {
                    Primitives.Add(startElement);
                    Calculator.Add(startElement.BoundingBox);
                }
            }

        }
    }
}